public struct VisionCameraCalibration: Sendable, Hashable {
    public let reference: VisionCalibrationReference
    public let source: String
    public let calibratedAt: VisionTimestamp
    public let validity: VisionTimeRange
    public let intrinsics: VisionCameraIntrinsics
    public let lensDistortion: VisionLensDistortionModel?

    public init(
        reference: VisionCalibrationReference,
        source: String,
        calibratedAt: VisionTimestamp,
        validity: VisionTimeRange,
        intrinsics: VisionCameraIntrinsics,
        lensDistortion: VisionLensDistortionModel? = nil
    ) throws(VisionCalibrationError) {
        guard calibratedAt.clockDomain == validity.clockDomain else {
            throw .incompatibleClockDomain(
                expected: validity.clockDomain,
                actual: calibratedAt.clockDomain
            )
        }
        let containsCalibration: Bool
        do {
            containsCalibration = try validity.contains(calibratedAt)
        } catch {
            throw .incompatibleClockDomain(
                expected: validity.clockDomain,
                actual: calibratedAt.clockDomain
            )
        }
        guard containsCalibration else {
            throw .calibrationTimestampOutsideValidity
        }

        self.reference = reference
        self.source = source
        self.calibratedAt = calibratedAt
        self.validity = validity
        self.intrinsics = intrinsics
        self.lensDistortion = lensDistortion
    }
}
