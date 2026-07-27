public struct VisionTrackReference: Sendable, Hashable {
    public let id: VisionTrackID
    public let source: String
    public let state: VisionTrackState
    public let firstObservationTimestamp: VisionTimestamp
    public let latestObservationTimestamp: VisionTimestamp
    public let confidence: Float
    public let observationCount: UInt64
    public let missedAnalysisCountBeforeObservation: Int
    public let predecessorTrackID: VisionTrackID?

    public init(
        id: VisionTrackID,
        source: String,
        state: VisionTrackState,
        firstObservationTimestamp: VisionTimestamp,
        latestObservationTimestamp: VisionTimestamp,
        confidence: Float,
        observationCount: UInt64,
        missedAnalysisCountBeforeObservation: Int,
        predecessorTrackID: VisionTrackID? = nil
    ) throws(VisionTrackingError) {
        guard !source.isEmpty else {
            throw .invalidTrackSource(source)
        }
        guard confidence.isFinite, (0 ... 1).contains(confidence) else {
            throw .invalidTrackingConfidence(confidence)
        }
        guard observationCount > 0 else {
            throw .invalidObservationCount(observationCount)
        }
        guard missedAnalysisCountBeforeObservation >= 0 else {
            throw .invalidMissedAnalysisCount(
                missedAnalysisCountBeforeObservation
            )
        }
        guard firstObservationTimestamp.clockDomain
            == latestObservationTimestamp.clockDomain
        else {
            throw .incompatibleTrackTimestampClockDomains(
                first: firstObservationTimestamp.clockDomain,
                latest: latestObservationTimestamp.clockDomain
            )
        }
        guard latestObservationTimestamp.time
            >= firstObservationTimestamp.time
        else {
            throw .trackTimestampPrecedesFirstObservation(
                first: firstObservationTimestamp,
                latest: latestObservationTimestamp
            )
        }

        self.id = id
        self.source = source
        self.state = state
        self.firstObservationTimestamp = firstObservationTimestamp
        self.latestObservationTimestamp = latestObservationTimestamp
        self.confidence = confidence
        self.observationCount = observationCount
        self.missedAnalysisCountBeforeObservation =
            missedAnalysisCountBeforeObservation
        self.predecessorTrackID = predecessorTrackID
    }
}
