import OpenCoreVideo

public struct VisionImagePlaneLayout: Sendable, Hashable {
    public let index: Int
    public let dimensions: CVPixelDimensions
    public let bytesPerRow: Int
    public let byteCount: Int

    public init(
        index: Int,
        dimensions: CVPixelDimensions,
        bytesPerRow: Int,
        byteCount: Int
    ) throws(VisionImageLayoutError) {
        guard index >= 0 else {
            throw .invalidPlaneIndex(index: index, planeCount: 0)
        }
        guard bytesPerRow > 0 else {
            throw .invalidBytesPerRow(bytesPerRow)
        }
        guard byteCount > 0 else {
            throw .invalidByteCount(byteCount)
        }

        let minimumByteCount = bytesPerRow.multipliedReportingOverflow(
            by: dimensions.height
        )
        guard !minimumByteCount.overflow else {
            throw .byteCountOverflow
        }
        guard byteCount >= minimumByteCount.partialValue else {
            throw .invalidByteCount(byteCount)
        }

        self.index = index
        self.dimensions = dimensions
        self.bytesPerRow = bytesPerRow
        self.byteCount = byteCount
    }
}
