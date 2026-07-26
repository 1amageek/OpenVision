import OpenCoreMedia

public struct VisionObservationProvenance: Sendable, Hashable {
    public let frameID: VisionFrameID?
    public let timestamp: VisionTimestamp?
    public let coordinateSpace: VisionCoordinateSpace
    public let calibration: VisionCalibrationReference?
    public let transformRevision: VisionCoordinateTransformRevision?

    public init(
        frameID: VisionFrameID?,
        timestamp: VisionTimestamp?,
        coordinateSpace: VisionCoordinateSpace,
        calibration: VisionCalibrationReference?,
        transformRevision: VisionCoordinateTransformRevision?
    ) {
        self.frameID = frameID
        self.timestamp = timestamp
        self.coordinateSpace = coordinateSpace
        self.calibration = calibration
        self.transformRevision = transformRevision
    }

    public static let unattributedNormalizedImage = Self(
        frameID: nil,
        timestamp: nil,
        coordinateSpace: .normalizedImage(source: nil),
        calibration: nil,
        transformRevision: nil
    )

    func validate(
        timeRange: CMTimeRange?
    ) throws(VisionTemporalError) {
        guard let timestamp, let timeRange else {
            return
        }
        guard
            timeRange.isValid,
            !timeRange.isIndefinite,
            timeRange.start.isNumeric,
            timeRange.duration.isNumeric
        else {
            throw .invalidTimeRange(timeRange)
        }
        if timeRange.isEmpty {
            guard timeRange.start == timestamp.time else {
                throw .timestampOutsideObservationTimeRange(timestamp)
            }
            return
        }
        guard timeRange.containsTime(timestamp.time) else {
            throw .timestampOutsideObservationTimeRange(timestamp)
        }
    }
}
