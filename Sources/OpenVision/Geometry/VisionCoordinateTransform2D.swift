public struct VisionCoordinateTransform2D: Sendable, Hashable {
    public let source: VisionCoordinateSpaceID
    public let destination: VisionCoordinateSpaceID
    public let revision: VisionCoordinateTransformRevision
    public let validity: VisionTimeRange
    public let calibration: VisionCalibrationReference?
    public let matrix: VisionMatrix3x3

    public init(
        source: VisionCoordinateSpaceID,
        destination: VisionCoordinateSpaceID,
        revision: VisionCoordinateTransformRevision,
        validity: VisionTimeRange,
        calibration: VisionCalibrationReference?,
        matrix: VisionMatrix3x3
    ) {
        self.source = source
        self.destination = destination
        self.revision = revision
        self.validity = validity
        self.calibration = calibration
        self.matrix = matrix
    }

    public func transformed(
        _ locatedPoint: VisionLocatedPoint2D
    ) throws(VisionCoordinateError) -> VisionLocatedPoint2D {
        guard locatedPoint.coordinateSpace == source else {
            throw .incompatibleCoordinateSpace(
                expected: source,
                actual: locatedPoint.coordinateSpace
            )
        }
        if let calibration, calibration != locatedPoint.calibration {
            throw .incompatibleCalibration(
                expected: calibration,
                actual: locatedPoint.calibration
            )
        }

        let isValid: Bool
        do {
            isValid = try validity.contains(locatedPoint.timestamp)
        } catch let error {
            throw .temporal(error)
        }
        guard isValid else {
            throw .expiredTransform(locatedPoint.timestamp)
        }

        let point = locatedPoint.point
        let x = matrix.row0.x * point.x
            + matrix.row0.y * point.y
            + matrix.row0.z
        let y = matrix.row1.x * point.x
            + matrix.row1.y * point.y
            + matrix.row1.z
        let scale = matrix.row2.x * point.x
            + matrix.row2.y * point.y
            + matrix.row2.z
        guard scale.isFinite, scale != 0 else {
            throw .invalidHomogeneousScale(scale)
        }
        return VisionLocatedPoint2D(
            point: try VisionPoint2D(
                x: x / scale,
                y: y / scale
            ),
            coordinateSpace: destination,
            timestamp: locatedPoint.timestamp,
            calibration: locatedPoint.calibration,
            transformRevision: revision
        )
    }
}
