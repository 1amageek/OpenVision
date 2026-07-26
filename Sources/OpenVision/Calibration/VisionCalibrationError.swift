public enum VisionCalibrationError: Error, Sendable, Equatable {
    case invalidPixelSize(Float)
    case invalidIntrinsicMatrix
    case invalidLensDistortion
    case incompatibleSource(expected: String, actual: String?)
    case incompatibleClockDomain(
        expected: VisionClockDomain,
        actual: VisionClockDomain
    )
    case calibrationTimestampOutsideValidity
    case missingCaptureClockDomain
    case captureTimestampOutsideValidity(VisionTimestamp)
}
