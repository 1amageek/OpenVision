public struct VisionObservationID: Sendable, Hashable {
    public let high: UInt64
    public let low: UInt64

    public init(
        high: UInt64,
        low: UInt64
    ) {
        self.high = high
        self.low = low
    }
}
