public struct HumanBodyPoseTrackingUpdate: Sendable, Hashable {
    public let frameID: VisionFrameID
    public let timestamp: VisionTimestamp
    public let wasAnalyzed: Bool
    public let observations: [TrackedHumanBodyPoseObservation]
    public let endedTrackIDs: [VisionTrackID]

    public init(
        frameID: VisionFrameID,
        timestamp: VisionTimestamp,
        wasAnalyzed: Bool,
        observations: [TrackedHumanBodyPoseObservation],
        endedTrackIDs: [VisionTrackID]
    ) {
        self.frameID = frameID
        self.timestamp = timestamp
        self.wasAnalyzed = wasAnalyzed
        self.observations = observations
        self.endedTrackIDs = endedTrackIDs
    }
}
