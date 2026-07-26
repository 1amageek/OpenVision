enum VisionProviderExecution {
    static func run<Result: Sendable>(
        session: any VisionProviderSession,
        executionID: VisionExecutionID,
        operation:
            @escaping @Sendable () async throws(VisionError) -> Result
    ) async throws(VisionError) -> Result {
        let outcome: Swift.Result<Result, VisionError> =
            await withTaskCancellationHandler(
                operation: {
                    await operationResult(operation)
                },
                onCancel: {
                    Task {
                        await session.cancel(executionID)
                    }
                }
            )

        if Task.isCancelled {
            await session.cancel(executionID)
            throw VisionError.cancelled(executionID)
        }
        switch outcome {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    private static func operationResult<Result: Sendable>(
        _ operation:
            @escaping @Sendable () async throws(VisionError) -> Result
    ) async -> Swift.Result<Result, VisionError> {
        do {
            return .success(try await operation())
        } catch let error {
            return .failure(error)
        }
    }
}
