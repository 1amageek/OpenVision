import OpenCoreMedia

public enum VisionTrackingError: Error, Sendable, Equatable {
    case invalidFrameAnalysisSpacing(CMTime)
    case invalidMaximumMissedAnalysisCount(Int)
    case invalidMaximumTrackCount(Int)
    case invalidMaximumNormalizedJointDistance(Float)
    case invalidTrackingConfidence(Float)
    case invalidTrackSource(String)
    case invalidObservationCount(UInt64)
    case invalidMissedAnalysisCount(Int)
    case incompatibleTrackTimestampClockDomains(
        first: VisionClockDomain,
        latest: VisionClockDomain
    )
    case trackTimestampPrecedesFirstObservation(
        first: VisionTimestamp,
        latest: VisionTimestamp
    )
    case missingFrameID
    case missingTimestamp
    case incompatibleFrameSource(expected: String, actual: String)
    case incompatibleClockDomain(
        expected: VisionClockDomain,
        actual: VisionClockDomain
    )
    case nonIncreasingFrameSequence(previous: UInt64, actual: UInt64)
    case nonIncreasingTimestamp(
        previous: VisionTimestamp,
        actual: VisionTimestamp
    )
    case observationFrameMismatch(
        observationID: VisionObservationID,
        expected: VisionFrameID,
        actual: VisionFrameID?
    )
    case observationTimestampMismatch(
        observationID: VisionObservationID,
        expected: VisionTimestamp,
        actual: VisionTimestamp?
    )
    case insufficientPoseGeometry(VisionObservationID)
    case concurrentExecution(VisionTrackingSessionID)
    case requestShutDown(VisionTrackingSessionID)
    case trackCapacityExceeded(maximum: Int)
    case identifierExhausted(VisionTrackingSessionID)
}
