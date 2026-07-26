import OpenVision
import Testing

@Suite("OpenVision input lifetime")
struct OpenVisionInputLifetimeTests {
    @Test("Provider releases the source lease after input consumption")
    func inputConsumedRelease() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let gate = OpenVisionTestInferenceGate()
        let releaseCounter = OpenVisionReleaseCounter()
        var fixture: (
            sample: CMImageSampleBuffer,
            address: UInt
        )? = try OpenVisionTestFixture.externalSample(
            releaseCounter: releaseCounter
        )
        let expectedAddress = try #require(fixture?.address)
        let input = try VisionImageInput(
            sampleBuffer: try #require(fixture?.sample)
        )
        fixture = nil

        let provider = try OpenVisionTestProvider(
            id: "lifetime-provider",
            model: model,
            observationMarker: 55,
            inferenceGate: gate,
            state: state
        )

        async let observations = VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model),
            operation: {
                () async throws(VisionError)
                    -> [HumanBodyPoseObservation] in
                try await DetectHumanBodyPoseRequest().perform(
                    on: input
                )
            }
        )

        await gate.waitForArrival()
        #expect(input.isReleased)
        #expect(state.snapshot().borrowedAddress == expectedAddress)
        #expect(releaseCounter.count == 1)
        await gate.release()
        _ = try await observations
        #expect(releaseCounter.count == 1)
    }

    @Test("Released input rejects a second byte borrow")
    func releasedInputRejectsBorrow() throws {
        let sample = try OpenVisionTestFixture.ownedSample()
        let input = try VisionImageInput(sampleBuffer: sample)
        #expect(input.releaseInput())
        #expect(!input.releaseInput())

        #expect(throws: VisionError.inputReleased) {
            try input.withReadBytes { _ in }
        }
    }
}
