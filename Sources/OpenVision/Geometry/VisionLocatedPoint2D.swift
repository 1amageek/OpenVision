public struct VisionLocatedPoint2D: Sendable, Hashable {
    public let point: VisionPoint2D
    public let coordinateSpace: VisionCoordinateSpaceID
    public let timestamp: VisionTimestamp
    public let calibration: VisionCalibrationReference?
    public let transformRevision: VisionCoordinateTransformRevision?

    public init(
        point: VisionPoint2D,
        coordinateSpace: VisionCoordinateSpaceID,
        timestamp: VisionTimestamp,
        calibration: VisionCalibrationReference?,
        transformRevision: VisionCoordinateTransformRevision? = nil
    ) {
        self.point = point
        self.coordinateSpace = coordinateSpace
        self.timestamp = timestamp
        self.calibration = calibration
        self.transformRevision = transformRevision
    }
}
