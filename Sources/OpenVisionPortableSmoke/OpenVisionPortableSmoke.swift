import OpenVision

@main
enum OpenVisionPortableSmoke {
    static func main() {
        do {
            try runPortableSmoke()
        } catch {
            fatalError("OpenVision portable smoke failed")
        }
    }

    nonisolated private static func runPortableSmoke() throws {
        var storageWord: UInt64 = 0
        try withUnsafeMutablePointer(to: &storageWord) { storagePointer in
            try runSmoke(
                baseAddress: UnsafeMutableRawPointer(storagePointer)
            )
        }
    }

    nonisolated private static func runSmoke(
        baseAddress: UnsafeMutableRawPointer
    ) throws {
        let dimensions = try CVPixelDimensions(width: 2, height: 1)
        let layout = try CVPackedPixelBufferLayout(
            dimensions: dimensions,
            pixelFormat: .bgra32,
            bytesPerPixel: 4,
            bytesPerRow: 8
        )
        let pixelBuffer = PortablePixelBuffer(
            layout: layout,
            baseAddress: baseAddress,
            byteCount: MemoryLayout<UInt64>.size
        )
        let sample = try CMImageSampleBuffer(
            imageBuffer: pixelBuffer,
            formatDescription: CMImmutableVideoFormatDescription(
                dimensions: dimensions,
                pixelFormat: .bgra32
            ),
            timing: CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: .zero,
                decodeTimeStamp: .invalid
            )
        )
        let clock = VisionClockDomain(
            id: "portable-clock",
            epoch: 1,
            kind: .deviceMonotonic
        )
        let validity = try VisionTimeRange(
            range: CMTimeRange(
                start: .zero,
                duration: CMTime(value: 1, timescale: 1)
            ),
            clockDomain: clock
        )
        let calibratedAt = try VisionTimestamp(
            time: .zero,
            clockDomain: clock
        )
        let calibration = try VisionCameraCalibration(
            reference: VisionCalibrationReference(
                id: "portable-camera",
                revision: 1
            ),
            source: "portable-camera",
            calibratedAt: calibratedAt,
            validity: validity,
            intrinsics: VisionCameraIntrinsics(
                matrix: .identity,
                referenceDimensions: dimensions
            )
        )
        let input = try VisionImageInput(
            sampleBuffer: sample,
            frameID: VisionFrameID(
                source: "portable-camera",
                sequence: 1
            ),
            clockDomain: clock,
            calibration: calibration
        )
        let borrowedAddress = try input.withReadBytes {
            address(of: $0)
        }

        precondition(input.layout.dimensions == dimensions)
        precondition(input.layout.pixelFormat == .bgra32)
        precondition(input.layout.byteCount == 8)
        precondition(input.storage == .retainedHost)
        precondition(input.timestamp == calibratedAt)
        precondition(input.sourceCoordinateSpace.origin == .upperLeft)
        precondition(input.observationCoordinateSpace.origin == .lowerLeft)
        precondition(
            input.observationProvenance.calibration ==
                calibration.reference
        )
        precondition(borrowedAddress == UInt(bitPattern: baseAddress))
        precondition(
            input.storage.transferModes.contains(
                .stagedHostToDevice(fullFrameCopyCount: 1)
            )
        )
        precondition(input.releaseInput())
        precondition(!input.releaseInput())
    }

    nonisolated private static func address(
        of bytes: borrowing Span<UInt8>
    ) -> UInt? {
        bytes.withUnsafeBufferPointer {
            $0.baseAddress.map { UInt(bitPattern: $0) }
        }
    }
}

/// A test-only non-owning pixel-buffer fixture for runtime verification.
///
/// The stack word in `runPortableSmoke()` owns the memory and outlives every
/// synchronous borrow. The address never escapes a borrow callback, the byte
/// count is fixed to the initialized word, and no allocation or byte copy is
/// performed by this fixture.
private final class PortablePixelBuffer: CVPixelBuffer {
    let layout: CVPackedPixelBufferLayout
    let byteCount: Int
    let accessCapabilities: CVPixelBufferAccessCapabilities = [.read]
    let attachments = CVBufferAttachments()

    private let baseAddressBits: UInt

    var dimensions: CVPixelDimensions {
        layout.dimensions
    }

    var pixelFormat: CVPixelFormatType {
        layout.pixelFormat
    }

    var bytesPerRow: Int {
        layout.bytesPerRow
    }

    init(
        layout: CVPackedPixelBufferLayout,
        baseAddress: UnsafeMutableRawPointer,
        byteCount: Int
    ) {
        self.layout = layout
        self.baseAddressBits = UInt(bitPattern: baseAddress)
        self.byteCount = byteCount
    }

    func withReadBytes(
        _ body: (borrowing Span<UInt8>) -> Void
    ) throws(CVPixelBufferError) {
        guard
            let baseAddress = UnsafeMutableRawPointer(
                bitPattern: baseAddressBits
            )
        else {
            throw .storageReleased
        }
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        body(
            Span(
                _unsafeStart: UnsafePointer(bytes),
                count: byteCount
            )
        )
    }

    func withWriteBytes(
        _ body: (inout MutableSpan<UInt8>) -> Void
    ) throws(CVPixelBufferError) {
        throw .unsupportedAccess(.write)
    }
}
