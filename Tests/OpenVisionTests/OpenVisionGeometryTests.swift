import OpenVision
import Testing

@Suite("OpenVision geometry and pose observations")
struct OpenVisionGeometryTests {
    @Test("Normalized geometry rejects invalid coordinates")
    func normalizedGeometryValidation() {
        #expect(throws: VisionGeometryError.coordinateOutOfRange(
            x: 1.1,
            y: 0.5
        )) {
            _ = try NormalizedPoint(x: 1.1, y: 0.5)
        }
        #expect(throws: VisionGeometryError.rectangleOutOfRange(
            x: 0.8,
            y: 0.2,
            width: 0.3,
            height: 0.5
        )) {
            _ = try NormalizedRect(
                x: 0.8,
                y: 0.2,
                width: 0.3,
                height: 0.5
            )
        }
    }

    @Test("Missing joints remain missing")
    func missingJointRemainsMissing() throws {
        let point = try NormalizedPoint(x: 0.5, y: 0.5)
        let nose = try Joint(
            location: point,
            jointName:
                HumanBodyPoseObservation.JointName.nose.rawValue,
            confidence: 0.75
        )
        let observation = try HumanBodyPoseObservation(
            id: VisionObservationID(high: 1, low: 2),
            confidence: 0.75,
            timeRange: nil,
            originatingRequestDescriptor:
                .detectHumanBodyPoseRequest(.revision2),
            joints: [.nose: nose]
        )

        #expect(observation.joint(for: .nose) == nose)
        #expect(observation.joint(for: .leftWrist) == nil)
        #expect(observation.availableJointNames == [.nose])
        #expect(observation.allJoints(in: .face) == [.nose: nose])
        #expect(observation.allJoints(in: .leftArm).isEmpty)
    }

    @Test("Observation rejects a mismatched joint vocabulary")
    func jointVocabularyMismatch() throws {
        let joint = try Joint(
            location: NormalizedPoint(x: 0.5, y: 0.5),
            jointName:
                HumanBodyPoseObservation.JointName.leftEye.rawValue,
            confidence: 1
        )

        #expect(throws: VisionError.jointNameMismatch(
            expected:
                HumanBodyPoseObservation.JointName.nose.rawValue,
            actual:
                HumanBodyPoseObservation.JointName.leftEye.rawValue
        )) {
            _ = try HumanBodyPoseObservation(
                id: VisionObservationID(high: 1, low: 1),
                confidence: 1,
                timeRange: nil,
                originatingRequestDescriptor: nil,
                joints: [.nose: joint]
            )
        }
    }
}
