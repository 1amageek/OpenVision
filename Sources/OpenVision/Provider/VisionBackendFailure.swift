public struct VisionBackendFailure: Sendable, Equatable {
    public let providerID: VisionProviderID
    public let operation: String
    public let code: Int32

    public init(
        providerID: VisionProviderID,
        operation: String,
        code: Int32
    ) {
        self.providerID = providerID
        self.operation = operation
        self.code = code
    }
}
