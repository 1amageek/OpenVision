import OpenCoreMedia
import OpenCoreVideo
import Synchronization

public final class VisionImageInput: Sendable {
    private struct State: Sendable {
        var sampleBuffer: (any CMSampleBuffer)?
    }

    public let orientation: VisionImageOrientation
    public let frameID: VisionFrameID?
    public let layout: VisionImageLayout
    public let storage: VisionImageStorageDescriptor
    public let timing: CMSampleTimingInfo

    private let state: Mutex<State>

    public var dimensions: CVPixelDimensions {
        layout.dimensions
    }

    public var pixelFormat: CVPixelFormatType {
        layout.pixelFormat
    }

    public var memoryDomain: VisionMemoryDomain {
        storage.memoryDomain
    }

    public var ownershipMode: VisionInputOwnershipMode {
        storage.ownershipMode
    }

    public init(
        sampleBuffer: any CMSampleBuffer,
        orientation: VisionImageOrientation = .up,
        frameID: VisionFrameID? = nil,
        storage: VisionImageStorageDescriptor = .retainedHost
    ) throws(VisionError) {
        let imageBuffer: any CVPixelBuffer & Sendable
        let timing: CMSampleTimingInfo
        do {
            imageBuffer = try sampleBuffer.imageBuffer()
            timing = try sampleBuffer.timingInfo(at: 0)
        } catch let error {
            throw .invalidSampleBuffer(error)
        }

        guard storage.accessModes.contains(.hostBytes) else {
            throw .unsupportedImageStorageAccess(.hostBytes)
        }
        guard imageBuffer.accessCapabilities.contains(.read) else {
            throw .unsupportedImageStorageAccess(.hostBytes)
        }

        self.orientation = orientation
        self.frameID = frameID
        layout = try VisionImageLayout.snapshot(of: imageBuffer)
        self.storage = storage
        self.timing = timing
        state = Mutex(State(sampleBuffer: sampleBuffer))
    }

    public var isReleased: Bool {
        state.withLock { state in
            state.sampleBuffer == nil
        }
    }

    public func withReadBytes<Output>(
        _ body:
            (borrowing Span<UInt8>) throws(VisionError) -> Output
    ) throws(VisionError) -> Output {
        let imageBuffer = try retainedImageBuffer()
        var invocationCount = 0
        var outcome: Swift.Result<Output, VisionError>?
        do {
            try imageBuffer.withReadBytes { bytes in
                invocationCount += 1
                guard invocationCount == 1 else {
                    return
                }
                do {
                    outcome = .success(try body(bytes))
                } catch let error as VisionError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(
                        .imageAccessFailure(
                            operation: "withReadBytes.body"
                        )
                    )
                }
            }
        } catch let error {
            throw .invalidPixelBuffer(error)
        }
        return try resolvedBorrowOutcome(
            outcome,
            invocationCount: invocationCount
        )
    }

    public func withReadBytes<Output>(
        ofPlane index: Int,
        _ body:
            (borrowing Span<UInt8>) throws(VisionError) -> Output
    ) throws(VisionError) -> Output {
        do {
            _ = try layout.plane(at: index)
        } catch let error {
            throw .invalidImageLayout(error)
        }

        let imageBuffer = try retainedImageBuffer()
        var invocationCount = 0
        var outcome: Swift.Result<Output, VisionError>?
        do {
            try imageBuffer.withReadBytes(
                ofPlane: index
            ) { bytes in
                invocationCount += 1
                guard invocationCount == 1 else {
                    return
                }
                do {
                    outcome = .success(try body(bytes))
                } catch let error as VisionError {
                    outcome = .failure(error)
                } catch {
                    outcome = .failure(
                        .imageAccessFailure(
                            operation: "withReadBytesOfPlane.body"
                        )
                    )
                }
            }
        } catch let error {
            throw .invalidPixelBuffer(error)
        }
        return try resolvedBorrowOutcome(
            outcome,
            invocationCount: invocationCount
        )
    }

    /// Releases the input owner's reference after an accelerator has consumed
    /// every byte borrowed from the source storage.
    ///
    /// A provider must complete or synchronize any asynchronous read before
    /// calling this method. Existing scoped borrows remain valid because they
    /// retain their image owner locally until the borrow returns.
    @discardableResult
    public func releaseInput() -> Bool {
        state.withLock { state in
            guard state.sampleBuffer != nil else {
                return false
            }
            state.sampleBuffer = nil
            return true
        }
    }

    private func retainedImageBuffer()
        throws(VisionError) -> any CVPixelBuffer & Sendable
    {
        let sampleBuffer = try state.withLock {
            state throws(VisionError) in
            guard let sampleBuffer = state.sampleBuffer else {
                throw .inputReleased
            }
            return sampleBuffer
        }

        do {
            return try sampleBuffer.imageBuffer()
        } catch let error {
            throw .invalidSampleBuffer(error)
        }
    }

    private func resolvedBorrowOutcome<Output>(
        _ outcome: Swift.Result<Output, VisionError>?,
        invocationCount: Int
    ) throws(VisionError) -> Output {
        guard invocationCount == 1, let outcome else {
            throw .invalidImageAccessInvocationCount(invocationCount)
        }
        switch outcome {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
