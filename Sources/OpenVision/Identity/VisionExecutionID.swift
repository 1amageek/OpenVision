public struct VisionExecutionID: Sendable, Hashable {
    public let sessionID: VisionProviderSessionID
    public let sequence: UInt64

    public init(
        sessionID: VisionProviderSessionID,
        sequence: UInt64
    ) {
        self.sessionID = sessionID
        self.sequence = sequence
    }
}
