import OpenCoreMedia
import OpenVision
import Testing

@Suite("OpenVision stateful human pose tracking")
struct OpenVisionStatefulTrackingTests {
    private let clockDomain = VisionClockDomain(
        id: "tracking-test-clock",
        epoch: 1,
        kind: .deviceMonotonic
    )

    @Test("Track references reject invalid source and timestamp provenance")
    func trackReferenceValidation() throws {
        let sessionID = VisionTrackingSessionID(high: 1, low: 2)
        let trackID = VisionTrackID(
            sessionID: sessionID,
            epoch: 0,
            sequence: 0
        )
        let first = try VisionTimestamp(
            time: CMTime(value: 2, timescale: 30),
            clockDomain: clockDomain
        )
        let earlier = try VisionTimestamp(
            time: CMTime(value: 1, timescale: 30),
            clockDomain: clockDomain
        )

        #expect(throws: VisionTrackingError.invalidTrackSource("")) {
            _ = try VisionTrackReference(
                id: trackID,
                source: "",
                state: .new,
                firstObservationTimestamp: first,
                latestObservationTimestamp: first,
                confidence: 1,
                observationCount: 1,
                missedAnalysisCountBeforeObservation: 0
            )
        }
        #expect(
            throws: VisionTrackingError
                .trackTimestampPrecedesFirstObservation(
                    first: first,
                    latest: earlier
                )
        ) {
            _ = try VisionTrackReference(
                id: trackID,
                source: "tracking-camera",
                state: .continued,
                firstObservationTimestamp: first,
                latestObservationTimestamp: earlier,
                confidence: 1,
                observationCount: 2,
                missedAnalysisCountBeforeObservation: 0
            )
        }
        #expect(
            throws: VisionTrackingError
                .invalidMaximumMissedAnalysisCount(Int.max)
        ) {
            _ = try TrackHumanBodyPoseRequest(
                trackingSessionID: sessionID,
                maximumMissedAnalysisCount: Int.max
            )
        }
    }

    @Test("One request preserves a visual track and reset changes epoch")
    func continuityAndReset() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "tracking-provider",
            model: model
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 10,
                low: 20
            )
        )
        let firstInput = try input(sequence: 1, timestampValue: 1)
        let secondInput = try input(sequence: 2, timestampValue: 2)
        let thirdInput = try input(sequence: 3, timestampValue: 3)

        let result = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> (
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            UInt64,
            HumanBodyPoseTrackingUpdate
        ) in
            let first = try await request.perform(
                on: firstInput
            )
            let second = try await request.perform(
                on: secondInput
            )
            let resetEpoch = try await request.reset()
            let third = try await request.perform(
                on: thirdInput
            )
            try await request.shutdown()
            return (first, second, resetEpoch, third)
        }

        let first = try #require(result.0.observations.first)
        let second = try #require(result.1.observations.first)
        let third = try #require(result.3.observations.first)
        #expect(first.track.state == .new)
        #expect(second.track.state == .continued)
        #expect(first.track.id == second.track.id)
        #expect(second.track.observationCount == 2)
        #expect(result.2 == 1)
        #expect(third.track.state == .new)
        #expect(third.track.id.epoch == 1)
        #expect(third.track.id != first.track.id)
    }

    @Test("Frame spacing skips inference without advancing a track")
    func frameAnalysisSpacing() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "spacing-provider",
            model: model,
            state: state
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 30,
                low: 40
            ),
            frameAnalysisSpacing: CMTime(value: 1, timescale: 30)
        )
        let firstInput = try input(
            sequence: 1,
            timestampValue: 0,
            timescale: 60
        )
        let skippedInput = try input(
            sequence: 2,
            timestampValue: 1,
            timescale: 60
        )
        let secondInput = try input(
            sequence: 3,
            timestampValue: 2,
            timescale: 60
        )

        let updates = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> (
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate
        ) in
            let first = try await request.perform(
                on: firstInput
            )
            let skipped = try await request.perform(
                on: skippedInput
            )
            let second = try await request.perform(
                on: secondInput
            )
            try await request.shutdown()
            return (first, skipped, second)
        }

        #expect(updates.0.wasAnalyzed)
        #expect(!updates.1.wasAnalyzed)
        #expect(updates.1.observations.isEmpty)
        #expect(updates.2.wasAnalyzed)
        #expect(
            updates.0.observations[0].track.id ==
                updates.2.observations[0].track.id
        )
        #expect(state.snapshot().executionCount == 2)
    }

    @Test("A bounded gap ends a track and a later pose starts a new one")
    func boundedGap() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "gap-provider",
            model: model,
            emptyBodyPoseFrameSequences: [2, 3]
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 50,
                low: 60
            ),
            maximumMissedAnalysisCount: 1
        )
        let firstInput = try input(sequence: 1, timestampValue: 1)
        let firstGapInput = try input(sequence: 2, timestampValue: 2)
        let secondGapInput = try input(sequence: 3, timestampValue: 3)
        let replacementInput = try input(sequence: 4, timestampValue: 4)

        let updates = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> (
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate
        ) in
            let first = try await request.perform(
                on: firstInput
            )
            let firstGap = try await request.perform(
                on: firstGapInput
            )
            let secondGap = try await request.perform(
                on: secondGapInput
            )
            let replacement = try await request.perform(
                on: replacementInput
            )
            try await request.shutdown()
            return (first, firstGap, secondGap, replacement)
        }

        let originalID = updates.0.observations[0].track.id
        #expect(updates.1.endedTrackIDs.isEmpty)
        #expect(updates.2.endedTrackIDs == [originalID])
        #expect(updates.3.observations[0].track.state == .new)
        #expect(updates.3.observations[0].track.id != originalID)
    }

    @Test("A pose returning within the gap budget is reacquired")
    func reacquisition() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "reacquisition-provider",
            model: model,
            emptyBodyPoseFrameSequences: [2]
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 61,
                low: 62
            ),
            maximumMissedAnalysisCount: 1
        )
        let firstInput = try input(sequence: 1, timestampValue: 1)
        let gapInput = try input(sequence: 2, timestampValue: 2)
        let returningInput = try input(sequence: 3, timestampValue: 3)

        let updates = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> (
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate
        ) in
            let first = try await request.perform(on: firstInput)
            let gap = try await request.perform(on: gapInput)
            let returning = try await request.perform(on: returningInput)
            try await request.shutdown()
            return (first, gap, returning)
        }

        let firstTrack = updates.0.observations[0].track
        let returningTrack = updates.2.observations[0].track
        #expect(updates.1.observations.isEmpty)
        #expect(updates.1.endedTrackIDs.isEmpty)
        #expect(returningTrack.id == firstTrack.id)
        #expect(returningTrack.state == VisionTrackState.reacquired)
        #expect(returningTrack.missedAnalysisCountBeforeObservation == 1)
        #expect(returningTrack.observationCount == 2)
    }

    @Test("Two spatially separated poses retain independent track IDs")
    func multiplePeople() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "multiple-people-provider",
            model: model,
            bodyPoseXCoordinatesByFrameSequence: [
                1: [0.2, 0.8],
                2: [0.75, 0.25],
                3: [0.3, 0.7]
            ]
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 63,
                low: 64
            ),
            maximumNormalizedJointDistance: 0.2
        )
        let firstInput = try input(sequence: 1, timestampValue: 1)
        let secondInput = try input(sequence: 2, timestampValue: 2)
        let thirdInput = try input(sequence: 3, timestampValue: 3)

        let updates = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> (
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate,
            HumanBodyPoseTrackingUpdate
        ) in
            let first = try await request.perform(on: firstInput)
            let second = try await request.perform(on: secondInput)
            let third = try await request.perform(on: thirdInput)
            try await request.shutdown()
            return (first, second, third)
        }

        let leftTrackID = try trackID(nearX: 0.2, in: updates.0)
        let rightTrackID = try trackID(nearX: 0.8, in: updates.0)
        #expect(leftTrackID != rightTrackID)
        #expect(try trackID(nearX: 0.25, in: updates.1) == leftTrackID)
        #expect(try trackID(nearX: 0.75, in: updates.1) == rightTrackID)
        #expect(try trackID(nearX: 0.3, in: updates.2) == leftTrackID)
        #expect(try trackID(nearX: 0.7, in: updates.2) == rightTrackID)
    }

    @Test("Track capacity failure is typed and leaves state resettable")
    func trackCapacity() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "tracking-capacity-provider",
            model: model,
            bodyPoseXCoordinatesByFrameSequence: [
                1: [0.2, 0.8]
            ]
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 69,
                low: 70
            ),
            maximumTrackCount: 1
        )
        let capacityInput = try input(sequence: 1, timestampValue: 1)

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            await #expect(
                throws: VisionError.tracking(
                    .trackCapacityExceeded(maximum: 1)
                )
            ) {
                _ = try await request.perform(on: capacityInput)
            }
            let epoch = try await request.reset()
            #expect(epoch == 1)
            try await request.shutdown()
        }

        #expect(capacityInput.isReleased)
    }

    @Test("Missing frame and timestamp metadata fail before inference")
    func requiredMetadata() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "metadata-provider",
            model: model,
            state: state
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 65,
                low: 66
            )
        )
        let missingFrameInput = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample(),
            clockDomain: clockDomain
        )
        let missingTimestampInput = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample(),
            frameID: VisionFrameID(
                source: "tracking-camera",
                sequence: 1
            )
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            await #expect(
                throws: VisionError.tracking(.missingFrameID)
            ) {
                _ = try await request.perform(on: missingFrameInput)
            }
            await #expect(
                throws: VisionError.tracking(.missingTimestamp)
            ) {
                _ = try await request.perform(on: missingTimestampInput)
            }
            try await request.shutdown()
        }

        #expect(missingFrameInput.isReleased)
        #expect(missingTimestampInput.isReleased)
        #expect(state.snapshot().executionCount == 0)
    }

    @Test("Tracking preserves the provider borrow address and releases input")
    func inputOwnership() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "tracking-ownership-provider",
            model: model,
            state: state
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 67,
                low: 68
            )
        )
        let releaseCounter = OpenVisionReleaseCounter()
        let external = try OpenVisionTestFixture.externalSample(
            releaseCounter: releaseCounter
        )
        let input = try VisionImageInput(
            sampleBuffer: external.sample,
            frameID: VisionFrameID(
                source: "tracking-camera",
                sequence: 1
            ),
            clockDomain: clockDomain
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            _ = try await request.perform(on: input)
            try await request.shutdown()
        }

        #expect(input.isReleased)
        #expect(state.snapshot().borrowedAddress == external.address)
        #expect(releaseCounter.count == 0)
    }

    @Test("Out-of-order timestamps and post-shutdown calls fail explicitly")
    func orderingAndShutdownFailures() async throws {
        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "order-provider",
            model: model
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 70,
                low: 80
            )
        )
        let firstInput = try input(sequence: 1, timestampValue: 2)
        let outOfOrderInput = try input(
            sequence: 2,
            timestampValue: 1
        )
        let shutDownInput = try input(
            sequence: 3,
            timestampValue: 3
        )
        let previousTimestamp = try VisionTimestamp(
            time: CMTime(value: 2, timescale: 30),
            clockDomain: clockDomain
        )
        let actualTimestamp = try VisionTimestamp(
            time: CMTime(value: 1, timescale: 30),
            clockDomain: clockDomain
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            _ = try await request.perform(
                on: firstInput
            )
            await #expect(
                throws: VisionError.tracking(
                    .nonIncreasingTimestamp(
                        previous: previousTimestamp,
                        actual: actualTimestamp
                    )
                )
            ) {
                _ = try await request.perform(on: outOfOrderInput)
            }
            #expect(outOfOrderInput.isReleased)

            try await request.shutdown()
            await #expect(
                throws: VisionError.tracking(
                    .requestShutDown(
                        VisionTrackingSessionID(high: 70, low: 80)
                    )
                )
            ) {
                _ = try await request.perform(on: shutDownInput)
            }
            #expect(shutDownInput.isReleased)
        }
    }

    @Test("One tracking epoch rejects source, clock, and frame-order changes")
    func sourceClockAndFrameOrdering() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "tracking-provenance-provider",
            model: model,
            state: state
        )
        let sessionID = VisionTrackingSessionID(high: 81, low: 82)
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: sessionID
        )
        let otherClock = VisionClockDomain(
            id: "other-tracking-clock",
            epoch: 1,
            kind: .deviceMonotonic
        )
        let firstInput = try input(sequence: 1, timestampValue: 1)
        let wrongSourceInput = try input(
            sequence: 2,
            timestampValue: 2,
            source: "other-camera"
        )
        let wrongClockInput = try input(
            sequence: 2,
            timestampValue: 2,
            clockDomain: otherClock
        )
        let validSecondInput = try input(
            sequence: 2,
            timestampValue: 2
        )
        let duplicateSequenceInput = try input(
            sequence: 2,
            timestampValue: 3
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            _ = try await request.perform(on: firstInput)
            await #expect(
                throws: VisionError.tracking(
                    .incompatibleFrameSource(
                        expected: "tracking-camera",
                        actual: "other-camera"
                    )
                )
            ) {
                _ = try await request.perform(on: wrongSourceInput)
            }
            await #expect(
                throws: VisionError.tracking(
                    .incompatibleClockDomain(
                        expected: clockDomain,
                        actual: otherClock
                    )
                )
            ) {
                _ = try await request.perform(on: wrongClockInput)
            }
            _ = try await request.perform(on: validSecondInput)
            await #expect(
                throws: VisionError.tracking(
                    .nonIncreasingFrameSequence(
                        previous: 2,
                        actual: 2
                    )
                )
            ) {
                _ = try await request.perform(on: duplicateSequenceInput)
            }
            try await request.shutdown()
        }

        #expect(wrongSourceInput.isReleased)
        #expect(wrongClockInput.isReleased)
        #expect(duplicateSequenceInput.isReleased)
        #expect(state.snapshot().executionCount == 2)
    }

    @Test("Concurrent execution on one stateful request is rejected")
    func concurrentExecution() async throws {
        let model = try OpenVisionTestFixture.model()
        let gate = OpenVisionTestInferenceGate()
        let provider = try OpenVisionTestProvider(
            id: "concurrent-provider",
            model: model,
            inferenceGate: gate
        )
        let sessionID = VisionTrackingSessionID(high: 90, low: 100)
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: sessionID
        )
        let firstInput = try input(
            sequence: 1,
            timestampValue: 1
        )
        let secondInput = try input(
            sequence: 2,
            timestampValue: 2
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            let firstTask = Task {
                await trackingResult(
                    request: request,
                    input: firstInput
                )
            }
            await gate.waitForArrival()

            await #expect(
                throws: VisionError.tracking(
                    .concurrentExecution(sessionID)
                )
            ) {
                _ = try await request.perform(on: secondInput)
            }
            #expect(secondInput.isReleased)

            await gate.release()
            switch await firstTask.value {
            case .success:
                break
            case .failure(let error):
                throw error
            }
            try await request.shutdown()
        }
    }

    @Test("Cancellation releases input and leaves the request resettable")
    func cancellation() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let gate = OpenVisionTestInferenceGate()
        let provider = try OpenVisionTestProvider(
            id: "tracking-cancellation-provider",
            model: model,
            inferenceGate: gate,
            state: state
        )
        let request = try TrackHumanBodyPoseRequest(
            trackingSessionID: VisionTrackingSessionID(
                high: 101,
                low: 102
            )
        )
        let firstInput = try input(
            sequence: 1,
            timestampValue: 1
        )

        try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model)
        ) { () async throws(VisionError) -> Void in
            let task = Task {
                await trackingResult(
                    request: request,
                    input: firstInput
                )
            }
            await gate.waitForArrival()
            task.cancel()
            await gate.release()

            switch await task.value {
            case .success:
                Issue.record("Cancelled tracking unexpectedly succeeded")
            case .failure(.cancelled):
                break
            case .failure(let error):
                Issue.record("Unexpected tracking failure: \(error)")
            }

            let epoch = try await request.reset()
            #expect(epoch == 1)
            try await request.shutdown()
        }

        #expect(firstInput.isReleased)
        #expect(state.snapshot().cancellationCount >= 1)
    }

    private func trackingResult(
        request: TrackHumanBodyPoseRequest,
        input: VisionImageInput
    ) async -> Result<HumanBodyPoseTrackingUpdate, VisionError> {
        do {
            return .success(try await request.perform(on: input))
        } catch let error {
            return .failure(error)
        }
    }

    private func trackID(
        nearX expectedX: Float,
        in update: HumanBodyPoseTrackingUpdate
    ) throws -> VisionTrackID {
        let observation = try #require(
            update.observations.first { observation in
                guard let nose = observation.pose.joint(for: .nose) else {
                    return false
                }
                return abs(nose.location.x - expectedX) < 0.001
            }
        )
        return observation.track.id
    }

    private func input(
        sequence: UInt64,
        timestampValue: CMTimeValue,
        timescale: CMTimeScale = 30,
        source: String = "tracking-camera",
        clockDomain: VisionClockDomain? = nil
    ) throws -> VisionImageInput {
        try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample(
                presentationTimeStamp: CMTime(
                    value: timestampValue,
                    timescale: timescale
                )
            ),
            frameID: VisionFrameID(
                source: source,
                sequence: sequence
            ),
            clockDomain: clockDomain ?? self.clockDomain
        )
    }
}
