public protocol VisionProvider: Sendable {
    var descriptor: VisionProviderDescriptor { get }
    var capabilities: VisionProviderCapabilities { get }

    func makeSession(
        configuration: VisionSessionConfiguration
    ) async throws(VisionError) -> any VisionProviderSession
}
