import OpenCoreMedia

public enum VisionTemporalError: Error, Sendable, Equatable {
    case invalidTimestamp(CMTime)
    case invalidTimeRange(CMTimeRange)
    case incompatibleClockDomain(
        expected: VisionClockDomain,
        actual: VisionClockDomain
    )
    case timestampOutsideValidityRange(VisionTimestamp)
    case timestampOutsideObservationTimeRange(VisionTimestamp)
}
