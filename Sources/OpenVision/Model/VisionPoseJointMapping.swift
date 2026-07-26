public enum VisionPoseJointTarget: Sendable, Hashable {
    case body(HumanBodyPoseObservation.JointName)
    case hand(
        chirality: HumanHandPoseObservation.Chirality?,
        joint: HumanHandPoseObservation.JointName
    )
}

public struct VisionPoseJointMapping: Sendable, Hashable {
    public enum DerivedConfidence: Sendable, Hashable {
        case minimum
    }

    public enum Source: Sendable, Hashable {
        case index(Int)
        case midpoint(
            first: Int,
            second: Int,
            confidence: DerivedConfidence
        )
    }

    public let target: VisionPoseJointTarget
    public let source: Source

    public init(
        target: VisionPoseJointTarget,
        source: Source
    ) throws(VisionModelManifestError) {
        switch source {
        case .index(let index):
            guard index >= 0 else {
                throw .invalidJointSourceIndex(index)
            }
        case .midpoint(let first, let second, _):
            guard first >= 0 else {
                throw .invalidJointSourceIndex(first)
            }
            guard second >= 0, first != second else {
                throw .invalidJointSourceIndex(second)
            }
        }

        self.target = target
        self.source = source
    }
}
