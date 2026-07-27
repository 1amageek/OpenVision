public struct VisionTrackID: Sendable, Hashable {
    public let sessionID: VisionTrackingSessionID
    public let epoch: UInt64
    public let sequence: UInt64

    public init(
        sessionID: VisionTrackingSessionID,
        epoch: UInt64,
        sequence: UInt64
    ) {
        self.sessionID = sessionID
        self.epoch = epoch
        self.sequence = sequence
    }
}
