public struct VisionModelStageDescriptor: Sendable, Hashable {
    public enum Operation: Sendable, Hashable {
        case personDetection
        case humanWholeBodyPose
        case humanHandPose
    }

    public let id: VisionModelStageID
    public let operation: Operation
    public let input: VisionModelInputDescriptor
    public let outputs: [VisionModelTensorDescriptor]
    public let provenance: VisionModelProvenance

    public init(
        id: VisionModelStageID,
        operation: Operation,
        input: VisionModelInputDescriptor,
        outputs: [VisionModelTensorDescriptor],
        provenance: VisionModelProvenance
    ) throws(VisionModelManifestError) {
        guard !id.rawValue.isEmpty else {
            throw .emptyStageID
        }
        guard !outputs.isEmpty else {
            throw .emptyStageOutputs(id)
        }
        var tensorIDs: Set<VisionModelTensorID> = []
        for output in outputs {
            guard tensorIDs.insert(output.id).inserted else {
                throw .duplicateTensorID(
                    stage: id,
                    tensor: output.id
                )
            }
        }

        self.id = id
        self.operation = operation
        self.input = input
        self.outputs = outputs
        self.provenance = provenance
    }

    public func output(
        identifiedBy id: VisionModelTensorID
    ) -> VisionModelTensorDescriptor? {
        outputs.first { $0.id == id }
    }
}
