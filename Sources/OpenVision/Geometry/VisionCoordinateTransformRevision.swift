public struct VisionCoordinateTransformRevision:
    RawRepresentable,
    Sendable,
    Hashable
{
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}
