import OpenCoreMedia
import OpenCoreVideo
import Synchronization

public final class VisionImageInput: Sendable {
    private struct State: Sendable {
        var sampleBuffer: (any CMSampleBuffer)?
    }

    public let orientation: VisionImageOrientation
    public let frameID: VisionFrameID?
    public let dimensions: CVPixelDimensions
    public let pixelFormat: CVPixelFormatType
    public let timing: CMSampleTimingInfo
    public let memoryDomain = VisionMemoryDomain.host
    public let ownershipMode = VisionInputOwnershipMode.retained

    private let state: Mutex<State>

    public init(
        sampleBuffer: any CMSampleBuffer,
        orientation: VisionImageOrientation = .up,
        frameID: VisionFrameID? = nil
    ) throws(VisionError) {
        let imageBuffer: any CVPixelBuffer & Sendable
        let timing: CMSampleTimingInfo
        do {
            imageBuffer = try sampleBuffer.imageBuffer()
            timing = try sampleBuffer.timingInfo(at: 0)
        } catch let error {
            throw .invalidSampleBuffer(error)
        }

        self.orientation = orientation
        self.frameID = frameID
        dimensions = imageBuffer.dimensions
        pixelFormat = imageBuffer.pixelFormat
        self.timing = timing
        state = Mutex(State(sampleBuffer: sampleBuffer))
    }

    public var isReleased: Bool {
        state.withLock { state in
            state.sampleBuffer == nil
        }
    }

    public func withReadBytes(
        _ body: (borrowing Span<UInt8>) -> Void
    ) throws(VisionError) {
        let imageBuffer = try retainedImageBuffer()
        do {
            try imageBuffer.withReadBytes(body)
        } catch let error {
            throw .invalidPixelBuffer(error)
        }
    }

    public func withReadBytes(
        ofPlane index: Int,
        _ body: (borrowing Span<UInt8>) -> Void
    ) throws(VisionError) {
        let imageBuffer = try retainedImageBuffer()
        do {
            try imageBuffer.withReadBytes(
                ofPlane: index,
                body
            )
        } catch let error {
            throw .invalidPixelBuffer(error)
        }
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
}
