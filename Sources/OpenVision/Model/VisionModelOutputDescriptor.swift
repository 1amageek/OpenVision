public struct VisionModelOutputDescriptor: Sendable, Hashable {
    public enum CoordinateTransform: Sendable, Hashable {
        case modelInputPixelsUpperLeftToNormalizedImageLowerLeft
    }

    public let schemaRevision: String
    public let stage: VisionModelStageID
    public let xDistribution: VisionModelTensorID
    public let yDistribution: VisionModelTensorID
    public let jointMappings: [VisionPoseJointMapping]
    public let minimumJointConfidence: Float
    public let coordinateTransform: CoordinateTransform

    public init(
        schemaRevision: String,
        stage: VisionModelStageID,
        xDistribution: VisionModelTensorID,
        yDistribution: VisionModelTensorID,
        jointMappings: [VisionPoseJointMapping],
        minimumJointConfidence: Float,
        coordinateTransform: CoordinateTransform
    ) throws(VisionModelManifestError) {
        guard !schemaRevision.isEmpty else {
            throw .emptyOutputSchemaRevision
        }
        guard !stage.rawValue.isEmpty else {
            throw .missingOutputStage(stage)
        }
        guard !xDistribution.rawValue.isEmpty else {
            throw .emptyTensorID
        }
        guard !yDistribution.rawValue.isEmpty else {
            throw .emptyTensorID
        }
        guard !jointMappings.isEmpty else {
            throw .emptyJointMappings
        }
        guard
            minimumJointConfidence.isFinite,
            (0 ... 1).contains(minimumJointConfidence)
        else {
            throw .invalidJointConfidence(
                minimumJointConfidence
            )
        }

        var targets: Set<VisionPoseJointTarget> = []
        for mapping in jointMappings {
            guard targets.insert(mapping.target).inserted else {
                throw .duplicateJointTarget(mapping.target)
            }
        }

        self.schemaRevision = schemaRevision
        self.stage = stage
        self.xDistribution = xDistribution
        self.yDistribution = yDistribution
        self.jointMappings = jointMappings
        self.minimumJointConfidence = minimumJointConfidence
        self.coordinateTransform = coordinateTransform
    }
}
