public struct VisionClockDomain: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case hostMonotonic
        case deviceMonotonic
        case synchronized
    }

    public let id: String
    public let epoch: UInt64
    public let kind: Kind

    public init(
        id: String,
        epoch: UInt64,
        kind: Kind
    ) {
        self.id = id
        self.epoch = epoch
        self.kind = kind
    }
}
