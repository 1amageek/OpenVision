public enum VisionCoordinateError: Error, Sendable, Equatable {
    case nonFiniteCoordinate
    case nonFiniteTransform
    case invalidHomogeneousScale(Float)
    case incompatibleCoordinateSpace(
        expected: VisionCoordinateSpaceID,
        actual: VisionCoordinateSpaceID
    )
    case incompatibleCalibration(
        expected: VisionCalibrationReference,
        actual: VisionCalibrationReference?
    )
    case expiredTransform(VisionTimestamp)
    case temporal(VisionTemporalError)
}
