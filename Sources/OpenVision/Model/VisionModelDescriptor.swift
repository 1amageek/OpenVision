public struct VisionModelDescriptor: Sendable, Hashable {
    public let id: String
    public let revision: String
    public let request: RequestDescriptor
    public let input: VisionModelInputDescriptor
    public let outputSchemaRevision: String

    public init(
        id: String,
        revision: String,
        request: RequestDescriptor,
        input: VisionModelInputDescriptor,
        outputSchemaRevision: String
    ) {
        self.id = id
        self.revision = revision
        self.request = request
        self.input = input
        self.outputSchemaRevision = outputSchemaRevision
    }
}
