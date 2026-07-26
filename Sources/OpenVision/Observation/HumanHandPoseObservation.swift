import OpenCoreMedia

public struct HumanHandPoseObservation:
    VisionObservation,
    PoseProviding
{
    public enum Chirality: Sendable, Hashable {
        case left
        case right
    }

    public enum JointName:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        case thumbTip
        case thumbIP
        case thumbMP
        case thumbCMC
        case indexTip
        case indexDIP
        case indexPIP
        case indexMCP
        case middleTip
        case middleDIP
        case middlePIP
        case middleMCP
        case ringTip
        case ringDIP
        case ringPIP
        case ringMCP
        case littleTip
        case littleDIP
        case littlePIP
        case littleMCP
        case wrist
    }

    public enum JointsGroupName:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        case thumb
        case indexFinger
        case middleFinger
        case ringFinger
        case littleFinger
    }

    public let id: VisionObservationID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let chirality: Chirality?

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
        chirality: Chirality?,
        joints: [JointName: Joint]
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

        self.id = id
        self.confidence = confidence
        self.timeRange = timeRange
        self.originatingRequestDescriptor =
            originatingRequestDescriptor
        self.chirality = chirality
        self.joints = joints
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
    ) -> JointsGroupName? {
        switch jointName {
        case .thumbTip, .thumbIP, .thumbMP, .thumbCMC:
            .thumb
        case .indexTip, .indexDIP, .indexPIP, .indexMCP:
            .indexFinger
        case .middleTip, .middleDIP, .middlePIP, .middleMCP:
            .middleFinger
        case .ringTip, .ringDIP, .ringPIP, .ringMCP:
            .ringFinger
        case .littleTip, .littleDIP, .littlePIP, .littleMCP:
            .littleFinger
        case .wrist:
            nil
        }
    }
}
