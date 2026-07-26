import OpenVision
import Testing

@Suite("OpenVision provenance contract")
struct OpenVisionProvenanceContractTests {
    @Test("Normalized points convert with an explicit image origin")
    func normalizedPointConversion() throws {
        let dimensions = try CVPixelDimensions(width: 100, height: 200)
        let point = try NormalizedPoint(x: 0.25, y: 0.75)
        let upperLeft = try point.toImageCoordinates(
            dimensions,
            origin: .upperLeft
        )
        let expectedImagePoint = try VisionPoint2D(x: 25, y: 50)
        #expect(upperLeft == expectedImagePoint)

        let roundTrip = try NormalizedPoint(
            imagePoint: upperLeft,
            in: dimensions,
            origin: .upperLeft
        )
        #expect(roundTrip == point)
        #expect(point.verticallyFlipped().y == 0.25)
    }

    @Test("Timestamp and range preserve their clock domain")
    func temporalContract() throws {
        let clock = VisionClockDomain(
            id: "camera-clock",
            epoch: 1,
            kind: .deviceMonotonic
        )
        let timestamp = try VisionTimestamp(
            time: CMTime(value: 5, timescale: 30),
            clockDomain: clock
        )
        let validity = try VisionTimeRange(
            range: CMTimeRange(
                start: .zero,
                duration: CMTime(value: 1, timescale: 1)
            ),
            clockDomain: clock
        )

        #expect(try validity.contains(timestamp))
        #expect(throws: VisionTemporalError.invalidTimestamp(.invalid)) {
            _ = try VisionTimestamp(
                time: .invalid,
                clockDomain: clock
            )
        }

        let otherClock = VisionClockDomain(
            id: "other-clock",
            epoch: 1,
            kind: .deviceMonotonic
        )
        let otherTimestamp = try VisionTimestamp(
            time: timestamp.time,
            clockDomain: otherClock
        )
        #expect(throws: VisionTemporalError.incompatibleClockDomain(
            expected: clock,
            actual: otherClock
        )) {
            _ = try validity.contains(otherTimestamp)
        }
    }

    @Test("Observation rejects timestamp outside its time range")
    func observationTimeRangeValidation() throws {
        let clock = VisionClockDomain(
            id: "camera-clock",
            epoch: 1,
            kind: .deviceMonotonic
        )
        let timestamp = try VisionTimestamp(
            time: CMTime(value: 2, timescale: 1),
            clockDomain: clock
        )
        let provenance = VisionObservationProvenance(
            frameID: nil,
            timestamp: timestamp,
            coordinateSpace: .normalizedImage(source: nil),
            calibration: nil,
            transformRevision: nil
        )
        let joint = try Joint(
            location: NormalizedPoint(x: 0.5, y: 0.5),
            jointName: HumanBodyPoseObservation.JointName.nose.rawValue,
            confidence: 1
        )

        #expect(throws: VisionError.temporal(
            .timestampOutsideObservationTimeRange(timestamp)
        )) {
            _ = try HumanBodyPoseObservation(
                id: VisionObservationID(high: 1, low: 1),
                confidence: 1,
                timeRange: CMTimeRange(
                    start: .zero,
                    duration: CMTime(value: 1, timescale: 1)
                ),
                originatingRequestDescriptor: nil,
                joints: [.nose: joint],
                provenance: provenance
            )
        }
    }

    @Test("Coordinate transform rejects stale or incompatible provenance")
    func coordinateTransformContract() throws {
        let clock = VisionClockDomain(
            id: "camera-clock",
            epoch: 2,
            kind: .deviceMonotonic
        )
        let validity = try VisionTimeRange(
            range: CMTimeRange(
                start: .zero,
                duration: CMTime(value: 10, timescale: 1)
            ),
            clockDomain: clock
        )
        let calibration = VisionCalibrationReference(
            id: "ceiling-camera",
            revision: 4
        )
        let matrix = VisionMatrix3x3(
            row0: try VisionVector3(x: 1, y: 0, z: 2),
            row1: try VisionVector3(x: 0, y: 1, z: 3),
            row2: try VisionVector3(x: 0, y: 0, z: 1)
        )
        let source = VisionCoordinateSpaceID(rawValue: "source")
        let destination = VisionCoordinateSpaceID(rawValue: "destination")
        let transform = VisionCoordinateTransform2D(
            source: source,
            destination: destination,
            revision: VisionCoordinateTransformRevision(rawValue: 7),
            validity: validity,
            calibration: calibration,
            matrix: matrix
        )
        let timestamp = try VisionTimestamp(
            time: CMTime(value: 2, timescale: 1),
            clockDomain: clock
        )
        let locatedPoint = VisionLocatedPoint2D(
            point: try VisionPoint2D(x: 1, y: 2),
            coordinateSpace: source,
            timestamp: timestamp,
            calibration: calibration
        )
        let transformed = try transform.transformed(locatedPoint)
        let expected = try VisionPoint2D(x: 3, y: 5)
        #expect(transformed.point == expected)
        #expect(transformed.coordinateSpace == destination)
        #expect(transformed.timestamp == timestamp)
        #expect(transformed.calibration == calibration)
        #expect(transformed.transformRevision == transform.revision)

        let wrongSource = VisionCoordinateSpaceID(rawValue: "wrong")
        #expect(throws: VisionCoordinateError.incompatibleCoordinateSpace(
            expected: source,
            actual: wrongSource
        )) {
            _ = try transform.transformed(
                VisionLocatedPoint2D(
                    point: locatedPoint.point,
                    coordinateSpace: wrongSource,
                    timestamp: timestamp,
                    calibration: calibration
                )
            )
        }

        let wrongCalibration = VisionCalibrationReference(
            id: calibration.id,
            revision: calibration.revision + 1
        )
        #expect(throws: VisionCoordinateError.incompatibleCalibration(
            expected: calibration,
            actual: wrongCalibration
        )) {
            _ = try transform.transformed(
                VisionLocatedPoint2D(
                    point: locatedPoint.point,
                    coordinateSpace: source,
                    timestamp: timestamp,
                    calibration: wrongCalibration
                )
            )
        }

        let expired = try VisionTimestamp(
            time: CMTime(value: 10, timescale: 1),
            clockDomain: clock
        )
        #expect(throws: VisionCoordinateError.expiredTransform(expired)) {
            _ = try transform.transformed(
                VisionLocatedPoint2D(
                    point: locatedPoint.point,
                    coordinateSpace: source,
                    timestamp: expired,
                    calibration: calibration
                )
            )
        }

        let otherClock = VisionClockDomain(
            id: "other-clock",
            epoch: clock.epoch,
            kind: clock.kind
        )
        let otherTimestamp = try VisionTimestamp(
            time: timestamp.time,
            clockDomain: otherClock
        )
        #expect(throws: VisionCoordinateError.temporal(
            .incompatibleClockDomain(
                expected: clock,
                actual: otherClock
            )
        )) {
            _ = try transform.transformed(
                VisionLocatedPoint2D(
                    point: locatedPoint.point,
                    coordinateSpace: source,
                    timestamp: otherTimestamp,
                    calibration: calibration
                )
            )
        }
    }

    @Test("Image input validates and preserves camera calibration")
    func calibratedInputProvenance() async throws {
        let source = "ceiling-camera"
        let clock = VisionClockDomain(
            id: "camera-clock",
            epoch: 3,
            kind: .deviceMonotonic
        )
        let calibration = try cameraCalibration(
            source: source,
            clock: clock
        )
        let frameID = VisionFrameID(
            source: source,
            sequence: 42
        )
        let input = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample(),
            frameID: frameID,
            clockDomain: clock,
            calibration: calibration
        )

        #expect(input.timestamp?.clockDomain == clock)
        #expect(input.sourceCoordinateSpace.origin == .upperLeft)
        #expect(input.sourceCoordinateSpace.units == .pixels)
        #expect(input.observationCoordinateSpace.origin == .lowerLeft)
        #expect(input.observationCoordinateSpace.units == .normalized)
        #expect(
            input.observationProvenance.calibration ==
                calibration.reference
        )

        let model = try OpenVisionTestFixture.model()
        let provider = try OpenVisionTestProvider(
            id: "provenance-provider",
            model: model
        )
        let observations = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(model: model),
            operation: {
                () async throws(VisionError)
                    -> [HumanBodyPoseObservation] in
                try await DetectHumanBodyPoseRequest().perform(on: input)
            }
        )
        #expect(observations[0].provenance == input.observationProvenance)
    }

    @Test("Image input rejects calibration from another source")
    func incompatibleCalibrationSource() throws {
        let clock = VisionClockDomain(
            id: "camera-clock",
            epoch: 4,
            kind: .deviceMonotonic
        )
        let calibration = try cameraCalibration(
            source: "camera-a",
            clock: clock
        )

        #expect(throws: VisionError.calibration(
            .incompatibleSource(
                expected: "camera-a",
                actual: "camera-b"
            )
        )) {
            _ = try VisionImageInput(
                sampleBuffer: OpenVisionTestFixture.ownedSample(),
                frameID: VisionFrameID(
                    source: "camera-b",
                    sequence: 1
                ),
                clockDomain: clock,
                calibration: calibration
            )
        }
    }

    @Test("Image input rejects a mismatched calibration clock")
    func incompatibleCalibrationClock() throws {
        let calibrationClock = VisionClockDomain(
            id: "calibration-clock",
            epoch: 5,
            kind: .deviceMonotonic
        )
        let captureClock = VisionClockDomain(
            id: "capture-clock",
            epoch: 5,
            kind: .deviceMonotonic
        )
        let calibration = try cameraCalibration(
            source: "camera-a",
            clock: calibrationClock
        )
        let frameID = VisionFrameID(
            source: "camera-a",
            sequence: 1
        )

        #expect(throws: VisionError.calibration(
            .incompatibleClockDomain(
                expected: calibrationClock,
                actual: captureClock
            )
        )) {
            _ = try VisionImageInput(
                sampleBuffer: OpenVisionTestFixture.ownedSample(),
                frameID: frameID,
                clockDomain: captureClock,
                calibration: calibration
            )
        }

        #expect(throws: VisionError.calibration(
            .missingCaptureClockDomain
        )) {
            _ = try VisionImageInput(
                sampleBuffer: OpenVisionTestFixture.ownedSample(),
                frameID: frameID,
                calibration: calibration
            )
        }
    }

    @Test("Camera intrinsics reject a non-pinhole matrix")
    func invalidIntrinsics() throws {
        let invalid = VisionMatrix3x3(
            row0: try VisionVector3(x: 0, y: 0, z: 1),
            row1: try VisionVector3(x: 0, y: 1, z: 1),
            row2: try VisionVector3(x: 0, y: 0, z: 1)
        )
        let dimensions = try CVPixelDimensions(width: 2, height: 1)

        #expect(throws: VisionCalibrationError.invalidIntrinsicMatrix) {
            _ = try VisionCameraIntrinsics(
                matrix: invalid,
                referenceDimensions: dimensions
            )
        }
    }

    private func cameraCalibration(
        source: String,
        clock: VisionClockDomain
    ) throws -> VisionCameraCalibration {
        let validity = try VisionTimeRange(
            range: CMTimeRange(
                start: .zero,
                duration: CMTime(value: 1, timescale: 1)
            ),
            clockDomain: clock
        )
        let calibratedAt = try VisionTimestamp(
            time: CMTime(value: 1, timescale: 30),
            clockDomain: clock
        )
        let intrinsics = try VisionCameraIntrinsics(
            matrix: .identity,
            referenceDimensions: CVPixelDimensions(
                width: 2,
                height: 1
            ),
            pixelSizeMillimeters: 0.0014
        )
        return try VisionCameraCalibration(
            reference: VisionCalibrationReference(
                id: source,
                revision: 1
            ),
            source: source,
            calibratedAt: calibratedAt,
            validity: validity,
            intrinsics: intrinsics
        )
    }
}
