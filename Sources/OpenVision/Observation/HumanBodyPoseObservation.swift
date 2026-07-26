import OpenCoreMedia

public struct HumanBodyPoseObservation:
    VisionObservation,
    PoseProviding
{
    public enum JointName:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        case leftEar
        case leftEye
        case rightEar
        case rightEye
        case neck
        case nose
        case leftShoulder
        case leftElbow
        case leftWrist
        case rightShoulder
        case rightElbow
        case rightWrist
        case root
        case leftHip
        case leftKnee
        case leftAnkle
        case rightHip
        case rightKnee
        case rightAnkle
    }

    public enum JointsGroupName:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        case face
        case torso
        case leftArm
        case rightArm
        case leftLeg
        case rightLeg
    }

    public let id: VisionObservationID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let provenance: VisionObservationProvenance
    public let leftHand: HumanHandPoseObservation?
    public let rightHand: HumanHandPoseObservation?

    private let joints: [JointName: Joint]

    public var availableJointNames: [JointName] {
        JointName.allCases.filter { joints[$0] != nil }
    }

    public var availableJointsGroupNames: [JointsGroupName] {
        JointsGroupName.allCases.filter {
            !allJoints(in: $0).isEmpty
        }
    }

    public init(
        id: VisionObservationID,
        confidence: Float,
        timeRange: CMTimeRange?,
        originatingRequestDescriptor: RequestDescriptor?,
        joints: [JointName: Joint],
        leftHand: HumanHandPoseObservation? = nil,
        rightHand: HumanHandPoseObservation? = nil,
        provenance: VisionObservationProvenance
    ) throws(VisionError) {
        guard confidence.isFinite, (0 ... 1).contains(confidence) else {
            throw .invalidConfidence(confidence)
        }
        for (name, joint) in joints {
            guard name.rawValue == joint.jointName else {
                throw .jointNameMismatch(
                    expected: name.rawValue,
                    actual: joint.jointName
                )
            }
        }
        do {
            try provenance.validate(timeRange: timeRange)
        } catch let error {
            throw .temporal(error)
        }

        self.id = id
        self.confidence = confidence
        self.timeRange = timeRange
        self.originatingRequestDescriptor =
            originatingRequestDescriptor
        self.provenance = provenance
        self.joints = joints
        self.leftHand = leftHand
        self.rightHand = rightHand
    }

    public func joint(for jointName: JointName) -> Joint? {
        joints[jointName]
    }

    public func allJoints(
        in groupName: JointsGroupName? = nil
    ) -> [JointName: Joint] {
        guard let groupName else {
            return joints
        }

        return joints.filter { name, _ in
            Self.group(for: name) == groupName
        }
    }

    private static func group(
        for jointName: JointName
    ) -> JointsGroupName {
        switch jointName {
        case .leftEar, .leftEye, .rightEar, .rightEye, .nose:
            .face
        case .neck, .root:
            .torso
        case .leftShoulder, .leftElbow, .leftWrist:
            .leftArm
        case .rightShoulder, .rightElbow, .rightWrist:
            .rightArm
        case .leftHip, .leftKnee, .leftAnkle:
            .leftLeg
        case .rightHip, .rightKnee, .rightAnkle:
            .rightLeg
        }
    }
}
