public struct VisionCalibrationReference: Sendable, Hashable {
    public let id: String
    public let revision: UInt64

    public init(
        id: String,
        revision: UInt64
    ) {
        self.id = id
        self.revision = revision
    }
}
