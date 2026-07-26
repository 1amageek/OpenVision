public struct VisionProviderSessionDescriptor: Sendable, Hashable {
    public let id: VisionProviderSessionID
    public let provider: VisionProviderDescriptor
    public let model: VisionModelDescriptor

    public init(
        id: VisionProviderSessionID,
        provider: VisionProviderDescriptor,
        model: VisionModelDescriptor
    ) {
        self.id = id
        self.provider = provider
        self.model = model
    }
}
