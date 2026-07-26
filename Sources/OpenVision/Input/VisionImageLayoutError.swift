import OpenCoreVideo

public enum VisionImageLayoutError: Error, Sendable, Equatable {
    case invalidBytesPerRow(Int)
    case invalidByteCount(Int)
    case byteCountOverflow
    case invalidPlaneCount(Int)
    case invalidPlaneIndex(index: Int, planeCount: Int)
    case nonContiguousPlaneIndex(expected: Int, actual: Int)
    case planeDimensionsExceedImage(
        plane: CVPixelDimensions,
        image: CVPixelDimensions
    )
}
