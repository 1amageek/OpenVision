public enum VisionModelManifestError: Error, Sendable, Equatable {
    case emptyManifestID
    case emptyManifestRevision
    case emptyStageList
    case emptyStageID
    case emptyStageOutputs(VisionModelStageID)
    case duplicateStageID(VisionModelStageID)
    case invalidInputDimensions(width: Int, height: Int)
    case invalidInputValue(String)
    case regionSourceRequiresRegionAffine
    case regionAffineRequiresRegionSource
    case invalidRegionSource(VisionModelStageID)
    case regionSourceMustPrecedeConsumer(
        source: VisionModelStageID,
        consumer: VisionModelStageID
    )
    case missingRegionTensor(
        stage: VisionModelStageID,
        tensor: VisionModelTensorID
    )
    case incompatibleRegionTensor(
        stage: VisionModelStageID,
        tensor: VisionModelTensorID
    )
    case incompatibleRegionStage(VisionModelStageID)
    case regionCountExceedsSource(
        requested: Int,
        available: Int
    )
    case emptyTensorID
    case duplicateTensorID(
        stage: VisionModelStageID,
        tensor: VisionModelTensorID
    )
    case emptyTensorShape(VisionModelTensorID)
    case invalidTensorDimension(VisionModelTensorID)
    case invalidTensorMeaning(VisionModelTensorID)
    case incompatibleTensorShape(VisionModelTensorID)
    case emptyOutputSchemaRevision
    case invalidJointConfidence(Float)
    case emptyJointMappings
    case duplicateJointTarget(VisionPoseJointTarget)
    case invalidJointSourceIndex(Int)
    case missingOutputStage(VisionModelStageID)
    case missingOutputTensor(
        stage: VisionModelStageID,
        tensor: VisionModelTensorID
    )
    case incompatibleOutputTensor(
        stage: VisionModelStageID,
        tensor: VisionModelTensorID
    )
    case incompatibleOutputOperation(
        VisionModelStageDescriptor.Operation,
        RequestDescriptor
    )
    case incompleteBodyJointVocabulary
    case incompleteHandJointVocabulary(
        HumanHandPoseObservation.Chirality?
    )
    case incompatibleJointTargetForRequest(
        VisionPoseJointTarget,
        RequestDescriptor
    )
    case emptyProvenanceField(String)
    case invalidSHA256Digest(String)
    case emptyPrecisionSet
    case invalidLatencyBudget(Double)
    case invalidMaximumPersonCount(Int)
    case incompatibleMaximumPersonCount(
        manifest: Int,
        output: Int
    )
}
