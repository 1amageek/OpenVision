import OpenCoreVideo

public struct VisionCameraIntrinsics: Sendable, Hashable {
    public let matrix: VisionMatrix3x3
    public let referenceDimensions: CVPixelDimensions
    public let pixelSizeMillimeters: Float?

    public init(
        matrix: VisionMatrix3x3,
        referenceDimensions: CVPixelDimensions,
        pixelSizeMillimeters: Float? = nil
    ) throws(VisionCalibrationError) {
        guard
            matrix.row0.x > 0,
            matrix.row1.y > 0,
            matrix.row2.x == 0,
            matrix.row2.y == 0,
            matrix.row2.z == 1
        else {
            throw .invalidIntrinsicMatrix
        }
        if let pixelSizeMillimeters {
            guard
                pixelSizeMillimeters.isFinite,
                pixelSizeMillimeters > 0
            else {
                throw .invalidPixelSize(pixelSizeMillimeters)
            }
        }
        self.matrix = matrix
        self.referenceDimensions = referenceDimensions
        self.pixelSizeMillimeters = pixelSizeMillimeters
    }
}
