public struct VisionProviderDescriptor: Sendable, Hashable {
    public let id: VisionProviderID
    public let revision: String

    public init(
        id: VisionProviderID,
        revision: String
    ) {
        self.id = id
        self.revision = revision
    }
}
