public enum VisionContext {
    struct Environment: Sendable {
        let session: any VisionProviderSession
        let capabilities: VisionProviderCapabilities
        let configuration: VisionSessionConfiguration
        let executionSequence: VisionExecutionSequence
    }

    @TaskLocal
    static var environment: Environment?

    public static func withProvider<Result: Sendable>(
        _ provider: any VisionProvider,
        configuration: VisionSessionConfiguration,
        operation:
            @Sendable () async throws(VisionError) -> Result
    ) async throws(VisionError) -> Result {
        guard provider.capabilities.transferModes.contains(
            configuration.transferMode
        ) else {
            throw .unsupportedTransferMode(configuration.transferMode)
        }
        let session = try await provider.makeSession(
            configuration: configuration
        )
        let environment = Environment(
            session: session,
            capabilities: provider.capabilities,
            configuration: configuration,
            executionSequence: VisionExecutionSequence()
        )

        let outcome: Swift.Result<Result, VisionError> =
            await $environment.withValue(environment) {
                await operationResult(operation)
            }

        let result: Result
        switch outcome {
        case .success(let value):
            result = value
        case .failure(let operationError):
            do {
                try await session.shutdown()
            } catch let cleanupError {
                throw .operationAndCleanup(
                    operation: operationError,
                    cleanup: cleanupError
                )
            }
            throw operationError
        }

        try await session.shutdown()
        return result
    }

    static func executionEnvironment()
        throws(VisionError) -> Environment
    {
        guard let environment else {
            throw .providerNotConfigured
        }
        return environment
    }

    private static func operationResult<Result: Sendable>(
        _ operation:
            @Sendable () async throws(VisionError) -> Result
    ) async -> Swift.Result<Result, VisionError> {
        do {
            return .success(try await operation())
        } catch let error {
            return .failure(error)
        }
    }
}
