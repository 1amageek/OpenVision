public struct VisionFrameID: Sendable, Hashable {
    public let source: String
    public let sequence: UInt64

    public init(
        source: String,
        sequence: UInt64
    ) {
        self.source = source
        self.sequence = sequence
    }
}
