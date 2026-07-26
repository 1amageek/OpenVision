public struct VisionProviderSessionDescriptor: Sendable, Hashable {
    public let id: VisionProviderSessionID
    public let provider: VisionProviderDescriptor
    public let model: VisionModelManifest

    public init(
        id: VisionProviderSessionID,
        provider: VisionProviderDescriptor,
        model: VisionModelManifest
    ) {
        self.id = id
        self.provider = provider
        self.model = model
    }
}
