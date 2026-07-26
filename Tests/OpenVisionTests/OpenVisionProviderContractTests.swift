import OpenVision
import Testing

@Suite("OpenVision provider contract")
struct OpenVisionProviderContractTests {
    @Test("Apple-shaped perform requires an explicit provider scope")
    func missingProviderIsTypedFailure() async throws {
        let sample = try OpenVisionTestFixture.ownedSample()
        let request = DetectHumanBodyPoseRequest()

        await #expect(throws: VisionError.providerNotConfigured) {
            _ = try await request.perform(on: sample)
        }
    }

    @Test("Body pose request executes and shuts down exactly once")
    func bodyPoseExecution() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "body-provider",
            model: model,
            observationMarker: 41,
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        let observations = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model),
            operation: {
                () async throws(VisionError)
                    -> [HumanBodyPoseObservation] in
                try await DetectHumanBodyPoseRequest().perform(
                    on: sample,
                    orientation: .right
                )
            }
        )

        #expect(observations.count == 1)
        #expect(observations[0].id.high == 41)
        #expect(
            observations[0].originatingRequestDescriptor ==
                RequestDescriptor.detectHumanBodyPoseRequest(
                    .revision2
                )
        )
        #expect(
            observations[0].timeRange?.start ==
                CMTime(value: 10, timescale: 30)
        )
        let snapshot = state.snapshot()
        #expect(snapshot.makeSessionCount == 1)
        #expect(snapshot.executionCount == 1)
        #expect(snapshot.shutdownCount == 1)
        #expect(snapshot.consumedInputCount == 1)
    }

    @Test("Unsupported pixel format fails without provider execution")
    func unsupportedPixelFormat() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "format-provider",
            model: model,
            pixelFormats: [.bgra32],
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample(
            pixelFormat: .rgba32
        )

        await #expect(throws: VisionError.unsupportedPixelFormat(
            .rgba32
        )) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }

        let snapshot = state.snapshot()
        #expect(snapshot.executionCount == 0)
        #expect(snapshot.shutdownCount == 1)
    }

    @Test("Unsupported input memory domain is a typed failure")
    func unsupportedInputMemoryDomain() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "memory-domain-provider",
            model: model,
            memoryDomains: [.device],
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        await #expect(throws: VisionError.unsupportedMemoryDomain(
            .host
        )) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }

        let snapshot = state.snapshot()
        #expect(snapshot.executionCount == 0)
        #expect(snapshot.shutdownCount == 1)
    }

    @Test("Unsupported input ownership is a typed failure")
    func unsupportedInputOwnership() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "ownership-provider",
            model: model,
            inputOwnershipModes: [.imported],
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        await #expect(
            throws: VisionError.unsupportedInputOwnershipMode(
                .retained
            )
        ) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }

        let snapshot = state.snapshot()
        #expect(snapshot.executionCount == 0)
        #expect(snapshot.shutdownCount == 1)
    }

    @Test("Task-local providers do not cross parallel scopes")
    func taskLocalIsolation() async throws {
        let model = try OpenVisionTestFixture.model()
        let firstProvider = try OpenVisionTestProvider(
            id: "first-provider",
            model: model,
            observationMarker: 101
        )
        let secondProvider = try OpenVisionTestProvider(
            id: "second-provider",
            model: model,
            observationMarker: 202
        )
        let firstSample = try OpenVisionTestFixture.ownedSample()
        let secondSample = try OpenVisionTestFixture.ownedSample()

        async let first = VisionContext.withProvider(
            firstProvider,
            configuration: VisionSessionConfiguration(model: model),
            operation: { () async throws(VisionError) -> UInt64 in
                try await DetectHumanBodyPoseRequest().perform(
                    on: firstSample
                )[0].id.high
            }
        )
        async let second = VisionContext.withProvider(
            secondProvider,
            configuration: VisionSessionConfiguration(model: model),
            operation: { () async throws(VisionError) -> UInt64 in
                try await DetectHumanBodyPoseRequest().perform(
                    on: secondSample
                )[0].id.high
            }
        )

        let values = try await (first, second)
        #expect(values.0 == 101)
        #expect(values.1 == 202)
    }

    @Test("Operation and cleanup failures are both preserved")
    func operationAndCleanupFailure() async throws {
        let model = try OpenVisionTestFixture.model()
        let operationFailure = VisionError.backend(
            VisionBackendFailure(
                providerID: VisionProviderID(rawValue: "failing"),
                operation: "execute",
                code: 7
            )
        )
        let cleanupFailure = VisionError.backend(
            VisionBackendFailure(
                providerID: VisionProviderID(rawValue: "failing"),
                operation: "shutdown",
                code: 8
            )
        )
        let provider = try OpenVisionTestProvider(
            id: "failing",
            model: model,
            behavior: .executionFailure(operationFailure),
            shutdownFailure: cleanupFailure
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        await #expect(throws: VisionError.operationAndCleanup(
            operation: operationFailure,
            cleanup: cleanupFailure
        )) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }
    }

    @Test("Cancellation reaches the active provider execution")
    func activeExecutionCancellation() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let inferenceGate = OpenVisionTestInferenceGate()
        let provider = try OpenVisionTestProvider(
            id: "cancellation-provider",
            model: model,
            inferenceGate: inferenceGate,
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        let task = Task {
            try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }

        await inferenceGate.waitForArrival()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Cancelled inference returned success")
        } catch let error as VisionError {
            guard case .cancelled = error else {
                Issue.record("Unexpected cancellation error")
                return
            }
        } catch {
            Issue.record("Cancellation escaped the typed failure contract")
        }

        let snapshot = state.snapshot()
        #expect(snapshot.cancellationCount == 1)
        #expect(snapshot.shutdownCount == 1)
        #expect(snapshot.consumedInputCount == 1)
    }

    @Test("Compute device selection is validated per stage")
    func computeDeviceSelectionStage() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "compute-stage-provider",
            model: model,
            state: state
        )
        let sample = try OpenVisionTestFixture.ownedSample()
        var request = DetectHumanBodyPoseRequest()
        request.setComputeDevice(
            VisionComputeDeviceID(rawValue: "test"),
            for: .postProcessing
        )
        let configuredRequest = request

        await #expect(throws: VisionError.unsupportedComputeDevice(
            VisionComputeDeviceID(rawValue: "test")
        )) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await configuredRequest.perform(on: sample)
                }
            )
        }

        let snapshot = state.snapshot()
        #expect(snapshot.executionCount == 0)
        #expect(snapshot.shutdownCount == 1)
    }
}
