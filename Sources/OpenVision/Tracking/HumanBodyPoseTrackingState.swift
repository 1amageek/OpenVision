import OpenCoreMedia

actor HumanBodyPoseTrackingState {
    private struct PoseSignature: Sendable {
        let joints:
            [HumanBodyPoseObservation.JointName: NormalizedPoint]
        let center: NormalizedPoint

        init(
            observation: HumanBodyPoseObservation
        ) throws(VisionTrackingError) {
            let sourceJoints = observation.allJoints()
            var joints:
                [HumanBodyPoseObservation.JointName: NormalizedPoint] = [:]
            joints.reserveCapacity(sourceJoints.count)
            var x: Float = 0
            var y: Float = 0
            var count: Float = 0
            for name in HumanBodyPoseObservation.JointName.allCases {
                guard let joint = sourceJoints[name] else {
                    continue
                }
                joints[name] = joint.location
                x += joint.location.x
                y += joint.location.y
                count += 1
            }
            guard count > 0 else {
                throw .insufficientPoseGeometry(observation.id)
            }
            do {
                center = try NormalizedPoint(
                    x: x / count,
                    y: y / count
                )
            } catch {
                throw .insufficientPoseGeometry(observation.id)
            }
            self.joints = joints
        }

        func distance(to other: PoseSignature) -> Float {
            var sum: Float = 0
            var count: Float = 0
            for name in HumanBodyPoseObservation.JointName.allCases {
                guard
                    let first = joints[name],
                    let second = other.joints[name]
                else {
                    continue
                }
                let deltaX = first.x - second.x
                let deltaY = first.y - second.y
                sum += (deltaX * deltaX + deltaY * deltaY).squareRoot()
                count += 1
            }
            if count > 0 {
                return sum / count
            }
            let deltaX = center.x - other.center.x
            let deltaY = center.y - other.center.y
            return (deltaX * deltaX + deltaY * deltaY).squareRoot()
        }
    }

    private struct ActiveTrack: Sendable {
        let id: VisionTrackID
        let source: String
        let firstTimestamp: VisionTimestamp
        var latestTimestamp: VisionTimestamp
        var signature: PoseSignature
        var confidence: Float
        var observationCount: UInt64
        var missedAnalysisCount: Int
    }

    private struct MatchCandidate: Sendable {
        let trackID: VisionTrackID
        let observationIndex: Int
        let distance: Float
    }

    private let sessionID: VisionTrackingSessionID
    private var epoch: UInt64 = 0
    private var nextTrackSequence: UInt64 = 0
    private var tracks: [VisionTrackID: ActiveTrack] = [:]
    private var source: String?
    private var clockDomain: VisionClockDomain?
    private var lastReceivedFrameID: VisionFrameID?
    private var lastReceivedTimestamp: VisionTimestamp?
    private var lastAnalyzedTimestamp: VisionTimestamp?
    private var isProcessing = false
    private var isShutDown = false

    init(sessionID: VisionTrackingSessionID) {
        self.sessionID = sessionID
    }

    func process(
        input: VisionImageInput,
        poseRequest: DetectHumanBodyPoseRequest,
        frameAnalysisSpacing: CMTime,
        maximumMissedAnalysisCount: Int,
        maximumTrackCount: Int,
        maximumNormalizedJointDistance: Float
    ) async throws(VisionError) -> HumanBodyPoseTrackingUpdate {
        guard !isShutDown else {
            throw .tracking(.requestShutDown(sessionID))
        }
        guard !isProcessing else {
            throw .tracking(.concurrentExecution(sessionID))
        }
        isProcessing = true
        defer {
            isProcessing = false
        }

        let frameID = try requiredFrameID(input.frameID)
        let timestamp = try requiredTimestamp(input.timestamp)
        try validateOrder(frameID: frameID, timestamp: timestamp)
        lastReceivedFrameID = frameID
        lastReceivedTimestamp = timestamp

        if let lastAnalyzedTimestamp {
            let elapsed = timestamp.time - lastAnalyzedTimestamp.time
            if elapsed < frameAnalysisSpacing {
                return HumanBodyPoseTrackingUpdate(
                    frameID: frameID,
                    timestamp: timestamp,
                    wasAnalyzed: false,
                    observations: [],
                    endedTrackIDs: []
                )
            }
        }

        let observations = try await poseRequest.perform(on: input)
        let update = try updateTracks(
            observations: observations,
            frameID: frameID,
            timestamp: timestamp,
            maximumMissedAnalysisCount: maximumMissedAnalysisCount,
            maximumTrackCount: maximumTrackCount,
            maximumNormalizedJointDistance:
                maximumNormalizedJointDistance
        )
        lastAnalyzedTimestamp = timestamp
        return update
    }

    func reset() throws(VisionError) -> UInt64 {
        guard !isShutDown else {
            throw .tracking(.requestShutDown(sessionID))
        }
        guard !isProcessing else {
            throw .tracking(.concurrentExecution(sessionID))
        }
        guard epoch < UInt64.max else {
            throw .tracking(.identifierExhausted(sessionID))
        }
        epoch += 1
        nextTrackSequence = 0
        tracks.removeAll(keepingCapacity: true)
        source = nil
        clockDomain = nil
        lastReceivedFrameID = nil
        lastReceivedTimestamp = nil
        lastAnalyzedTimestamp = nil
        return epoch
    }

    func shutdown() throws(VisionError) {
        if isShutDown {
            return
        }
        guard !isProcessing else {
            throw .tracking(.concurrentExecution(sessionID))
        }
        tracks.removeAll(keepingCapacity: false)
        source = nil
        clockDomain = nil
        lastReceivedFrameID = nil
        lastReceivedTimestamp = nil
        lastAnalyzedTimestamp = nil
        isShutDown = true
    }

    private func requiredFrameID(
        _ frameID: VisionFrameID?
    ) throws(VisionError) -> VisionFrameID {
        guard let frameID else {
            throw .tracking(.missingFrameID)
        }
        return frameID
    }

    private func requiredTimestamp(
        _ timestamp: VisionTimestamp?
    ) throws(VisionError) -> VisionTimestamp {
        guard let timestamp else {
            throw .tracking(.missingTimestamp)
        }
        return timestamp
    }

    private func validateOrder(
        frameID: VisionFrameID,
        timestamp: VisionTimestamp
    ) throws(VisionError) {
        if let source, source != frameID.source {
            throw .tracking(
                .incompatibleFrameSource(
                    expected: source,
                    actual: frameID.source
                )
            )
        }
        if let clockDomain, clockDomain != timestamp.clockDomain {
            throw .tracking(
                .incompatibleClockDomain(
                    expected: clockDomain,
                    actual: timestamp.clockDomain
                )
            )
        }
        if let lastReceivedFrameID,
           frameID.sequence <= lastReceivedFrameID.sequence {
            throw .tracking(
                .nonIncreasingFrameSequence(
                    previous: lastReceivedFrameID.sequence,
                    actual: frameID.sequence
                )
            )
        }
        if let lastReceivedTimestamp,
           timestamp.time <= lastReceivedTimestamp.time {
            throw .tracking(
                .nonIncreasingTimestamp(
                    previous: lastReceivedTimestamp,
                    actual: timestamp
                )
            )
        }
        source = frameID.source
        clockDomain = timestamp.clockDomain
    }

    private func updateTracks(
        observations: [HumanBodyPoseObservation],
        frameID: VisionFrameID,
        timestamp: VisionTimestamp,
        maximumMissedAnalysisCount: Int,
        maximumTrackCount: Int,
        maximumNormalizedJointDistance: Float
    ) throws(VisionError) -> HumanBodyPoseTrackingUpdate {
        var signatures: [PoseSignature] = []
        signatures.reserveCapacity(observations.count)
        for observation in observations {
            guard observation.provenance.frameID == frameID else {
                throw .tracking(
                    .observationFrameMismatch(
                        observationID: observation.id,
                        expected: frameID,
                        actual: observation.provenance.frameID
                    )
                )
            }
            guard observation.provenance.timestamp == timestamp else {
                throw .tracking(
                    .observationTimestampMismatch(
                        observationID: observation.id,
                        expected: timestamp,
                        actual: observation.provenance.timestamp
                    )
                )
            }
            do {
                signatures.append(
                    try PoseSignature(observation: observation)
                )
            } catch let error {
                throw .tracking(error)
            }
        }

        let orderedTracks = tracks.values.sorted {
            if $0.id.epoch != $1.id.epoch {
                return $0.id.epoch < $1.id.epoch
            }
            return $0.id.sequence < $1.id.sequence
        }
        var candidates: [MatchCandidate] = []
        candidates.reserveCapacity(orderedTracks.count * signatures.count)
        for track in orderedTracks {
            for (index, signature) in signatures.enumerated() {
                let distance = track.signature.distance(to: signature)
                guard distance <= maximumNormalizedJointDistance else {
                    continue
                }
                candidates.append(
                    MatchCandidate(
                        trackID: track.id,
                        observationIndex: index,
                        distance: distance
                    )
                )
            }
        }
        candidates.sort {
            if $0.distance != $1.distance {
                return $0.distance < $1.distance
            }
            if $0.trackID.sequence != $1.trackID.sequence {
                return $0.trackID.sequence < $1.trackID.sequence
            }
            return $0.observationIndex < $1.observationIndex
        }

        var updatedTracks = tracks
        var matchedTrackIDs: Set<VisionTrackID> = []
        var matchedObservationIndices: Set<Int> = []
        var trackedObservations:
            [TrackedHumanBodyPoseObservation?] =
            Array(repeating: nil, count: observations.count)

        for candidate in candidates {
            guard
                !matchedTrackIDs.contains(candidate.trackID),
                !matchedObservationIndices.contains(
                    candidate.observationIndex
                ),
                var track = updatedTracks[candidate.trackID]
            else {
                continue
            }
            let missedCount = track.missedAnalysisCount
            track.latestTimestamp = timestamp
            track.signature = signatures[candidate.observationIndex]
            let associationConfidence = max(
                0,
                1 - candidate.distance
                    / maximumNormalizedJointDistance
            )
            track.confidence = min(
                observations[candidate.observationIndex].confidence,
                associationConfidence
            )
            guard track.observationCount < UInt64.max else {
                throw .tracking(.identifierExhausted(sessionID))
            }
            track.observationCount += 1
            track.missedAnalysisCount = 0
            updatedTracks[candidate.trackID] = track
            matchedTrackIDs.insert(candidate.trackID)
            matchedObservationIndices.insert(candidate.observationIndex)

            let state: VisionTrackState =
                missedCount == 0 ? .continued : .reacquired
            let reference: VisionTrackReference
            do {
                reference = try VisionTrackReference(
                    id: track.id,
                    source: track.source,
                    state: state,
                    firstObservationTimestamp: track.firstTimestamp,
                    latestObservationTimestamp: timestamp,
                    confidence: track.confidence,
                    observationCount: track.observationCount,
                    missedAnalysisCountBeforeObservation: missedCount
                )
            } catch let error {
                throw .tracking(error)
            }
            trackedObservations[candidate.observationIndex] =
                TrackedHumanBodyPoseObservation(
                    pose: observations[candidate.observationIndex],
                    track: reference
                )
        }

        var endedTrackIDs: [VisionTrackID] = []
        for track in orderedTracks where !matchedTrackIDs.contains(track.id) {
            guard var updatedTrack = updatedTracks[track.id] else {
                continue
            }
            updatedTrack.missedAnalysisCount += 1
            if updatedTrack.missedAnalysisCount
                > maximumMissedAnalysisCount {
                updatedTracks.removeValue(forKey: track.id)
                endedTrackIDs.append(track.id)
            } else {
                updatedTracks[track.id] = updatedTrack
            }
        }

        let newObservationIndices = observations.indices.filter {
            !matchedObservationIndices.contains($0)
        }
        guard updatedTracks.count + newObservationIndices.count
            <= maximumTrackCount
        else {
            throw .tracking(
                .trackCapacityExceeded(maximum: maximumTrackCount)
            )
        }
        var updatedNextTrackSequence = nextTrackSequence
        for index in newObservationIndices {
            guard updatedNextTrackSequence < UInt64.max else {
                throw .tracking(.identifierExhausted(sessionID))
            }
            let trackID = VisionTrackID(
                sessionID: sessionID,
                epoch: epoch,
                sequence: updatedNextTrackSequence
            )
            updatedNextTrackSequence += 1
            let track = ActiveTrack(
                id: trackID,
                source: frameID.source,
                firstTimestamp: timestamp,
                latestTimestamp: timestamp,
                signature: signatures[index],
                confidence: observations[index].confidence,
                observationCount: 1,
                missedAnalysisCount: 0
            )
            updatedTracks[trackID] = track
            let reference: VisionTrackReference
            do {
                reference = try VisionTrackReference(
                    id: trackID,
                    source: frameID.source,
                    state: .new,
                    firstObservationTimestamp: timestamp,
                    latestObservationTimestamp: timestamp,
                    confidence: observations[index].confidence,
                    observationCount: 1,
                    missedAnalysisCountBeforeObservation: 0
                )
            } catch let error {
                throw .tracking(error)
            }
            trackedObservations[index] =
                TrackedHumanBodyPoseObservation(
                    pose: observations[index],
                    track: reference
                )
        }

        tracks = updatedTracks
        nextTrackSequence = updatedNextTrackSequence
        return HumanBodyPoseTrackingUpdate(
            frameID: frameID,
            timestamp: timestamp,
            wasAnalyzed: true,
            observations: trackedObservations.compactMap { $0 },
            endedTrackIDs: endedTrackIDs
        )
    }
}
