public struct VisionModelManifest: Sendable, Hashable {
    public let id: String
    public let revision: String
    public let request: RequestDescriptor
    public let stages: [VisionModelStageDescriptor]
    public let output: VisionModelOutputDescriptor
    public let quality: VisionModelQualityRequirements

    public init(
        id: String,
        revision: String,
        request: RequestDescriptor,
        stages: [VisionModelStageDescriptor],
        output: VisionModelOutputDescriptor,
        quality: VisionModelQualityRequirements
    ) throws(VisionModelManifestError) {
        guard !id.isEmpty else {
            throw .emptyManifestID
        }
        guard !revision.isEmpty else {
            throw .emptyManifestRevision
        }
        guard !stages.isEmpty else {
            throw .emptyStageList
        }

        var stageIndices: [VisionModelStageID: Int] = [:]
        for (index, stage) in stages.enumerated() {
            guard stageIndices[stage.id] == nil else {
                throw .duplicateStageID(stage.id)
            }
            stageIndices[stage.id] = index
        }

        for (consumerIndex, stage) in stages.enumerated() {
            guard case .regions(
                let sourceStageID,
                let sourceTensorID,
                _,
                let maximumCount,
                _
            ) = stage.input.source else {
                continue
            }
            guard let sourceIndex = stageIndices[sourceStageID] else {
                throw .invalidRegionSource(sourceStageID)
            }
            guard sourceIndex < consumerIndex else {
                throw .regionSourceMustPrecedeConsumer(
                    source: sourceStageID,
                    consumer: stage.id
                )
            }
            let sourceStage = stages[sourceIndex]
            guard sourceStage.operation == .personDetection else {
                throw .incompatibleRegionStage(sourceStageID)
            }
            guard let sourceTensor = sourceStage.output(
                identifiedBy: sourceTensorID
            ) else {
                throw .missingRegionTensor(
                    stage: sourceStageID,
                    tensor: sourceTensorID
                )
            }
            guard case .personDetections(
                let availableCount
            ) = sourceTensor.meaning else {
                throw .incompatibleRegionTensor(
                    stage: sourceStageID,
                    tensor: sourceTensorID
                )
            }
            guard maximumCount <= availableCount else {
                throw .regionCountExceedsSource(
                    requested: maximumCount,
                    available: availableCount
                )
            }
        }

        guard let outputStageIndex = stageIndices[output.stage] else {
            throw .missingOutputStage(output.stage)
        }
        let outputStage = stages[outputStageIndex]
        switch (request, outputStage.operation) {
        case (
            .detectHumanBodyPoseRequest,
            .humanWholeBodyPose
        ), (
            .detectHumanHandPoseRequest,
            .humanHandPose
        ):
            break
        default:
            throw .incompatibleOutputOperation(
                outputStage.operation,
                request
            )
        }
        let xTensor = try Self.outputTensor(
            output.xDistribution,
            in: outputStage
        )
        let yTensor = try Self.outputTensor(
            output.yDistribution,
            in: outputStage
        )
        let outputContract = try Self.validatedSimCC(
            xTensor: xTensor,
            yTensor: yTensor,
            input: outputStage.input,
            stage: outputStage.id
        )
        try Self.validateJointMappings(
            output.jointMappings,
            jointCount: outputContract.jointCount,
            request: request
        )
        guard
            quality.maximumPersonCount ==
                outputContract.batchMaximum
        else {
            throw .incompatibleMaximumPersonCount(
                manifest: quality.maximumPersonCount,
                output: outputContract.batchMaximum
            )
        }
        if case .regions(
            _,
            _,
            _,
            let regionMaximumCount,
            _
        ) = outputStage.input.source {
            guard
                regionMaximumCount ==
                    outputContract.batchMaximum
            else {
                throw .incompatibleMaximumPersonCount(
                    manifest: regionMaximumCount,
                    output: outputContract.batchMaximum
                )
            }
        }

        self.id = id
        self.revision = revision
        self.request = request
        self.stages = stages
        self.output = output
        self.quality = quality
    }

    public func stage(
        identifiedBy id: VisionModelStageID
    ) -> VisionModelStageDescriptor? {
        stages.first { $0.id == id }
    }

    private static func outputTensor(
        _ id: VisionModelTensorID,
        in stage: VisionModelStageDescriptor
    ) throws(VisionModelManifestError)
        -> VisionModelTensorDescriptor
    {
        guard let tensor = stage.output(identifiedBy: id) else {
            throw .missingOutputTensor(
                stage: stage.id,
                tensor: id
            )
        }
        return tensor
    }

    private static func validatedSimCC(
        xTensor: VisionModelTensorDescriptor,
        yTensor: VisionModelTensorDescriptor,
        input: VisionModelInputDescriptor,
        stage: VisionModelStageID
    ) throws(VisionModelManifestError) -> (
        jointCount: Int,
        batchMaximum: Int
    ) {
        guard case .simCC(
            .x,
            let xJointCount,
            let xSplitRatio
        ) = xTensor.meaning else {
            throw .incompatibleOutputTensor(
                stage: stage,
                tensor: xTensor.id
            )
        }
        guard case .simCC(
            .y,
            let yJointCount,
            let ySplitRatio
        ) = yTensor.meaning else {
            throw .incompatibleOutputTensor(
                stage: stage,
                tensor: yTensor.id
            )
        }
        guard
            xJointCount == yJointCount,
            xSplitRatio == ySplitRatio,
            case .batch(let xBatchMaximum) = xTensor.shape[0],
            case .batch(let yBatchMaximum) = yTensor.shape[0],
            xBatchMaximum == yBatchMaximum,
            Self.matchesSimCCShape(
                xTensor.shape,
                jointCount: xJointCount,
                axisLength: input.width,
                splitRatio: xSplitRatio
            ),
            Self.matchesSimCCShape(
                yTensor.shape,
                jointCount: yJointCount,
                axisLength: input.height,
                splitRatio: ySplitRatio
            )
        else {
            throw .incompatibleOutputTensor(
                stage: stage,
                tensor: xTensor.id
            )
        }
        return (xJointCount, xBatchMaximum)
    }

    private static func matchesSimCCShape(
        _ shape: [VisionModelTensorDescriptor.Dimension],
        jointCount: Int,
        axisLength: Int,
        splitRatio: Float
    ) -> Bool {
        guard shape.count == 3 else {
            return false
        }
        guard case .batch = shape[0] else {
            return false
        }
        guard case .fixed(jointCount) = shape[1] else {
            return false
        }
        let expectedLength = Int(
            (Float(axisLength) * splitRatio).rounded()
        )
        guard case .fixed(expectedLength) = shape[2] else {
            return false
        }
        return true
    }

    private static func validateJointMappings(
        _ mappings: [VisionPoseJointMapping],
        jointCount: Int,
        request: RequestDescriptor
    ) throws(VisionModelManifestError) {
        for mapping in mappings {
            switch mapping.source {
            case .index(let index):
                guard index < jointCount else {
                    throw .invalidJointSourceIndex(index)
                }
            case .midpoint(let first, let second, _):
                guard first < jointCount else {
                    throw .invalidJointSourceIndex(first)
                }
                guard second < jointCount else {
                    throw .invalidJointSourceIndex(second)
                }
            }
        }

        switch request {
        case .detectHumanBodyPoseRequest:
            for mapping in mappings {
                if case .hand(nil, _) = mapping.target {
                    throw .incompatibleJointTargetForRequest(
                        mapping.target,
                        request
                    )
                }
            }
            let bodyJoints = Set<
                HumanBodyPoseObservation.JointName
            >(mappings.compactMap {
                guard case .body(let joint) = $0.target else {
                    return nil
                }
                return joint
            })
            guard bodyJoints == Set(
                HumanBodyPoseObservation.JointName.allCases
            ) else {
                throw .incompleteBodyJointVocabulary
            }
            try validateHandVocabulary(
                .left,
                mappings: mappings
            )
            try validateHandVocabulary(
                .right,
                mappings: mappings
            )
        case .detectHumanHandPoseRequest:
            for mapping in mappings {
                switch mapping.target {
                case .body, .hand(.some, _):
                    throw .incompatibleJointTargetForRequest(
                        mapping.target,
                        request
                    )
                case .hand(nil, _):
                    break
                }
            }
            try validateHandVocabulary(
                nil,
                mappings: mappings
            )
        }
    }

    private static func validateHandVocabulary(
        _ chirality: HumanHandPoseObservation.Chirality?,
        mappings: [VisionPoseJointMapping]
    ) throws(VisionModelManifestError) {
        let handJoints = Set<
            HumanHandPoseObservation.JointName
        >(mappings.compactMap {
            guard case .hand(
                let mappingChirality,
                let joint
            ) = $0.target, mappingChirality == chirality else {
                return nil
            }
            return joint
        })
        guard
            handJoints.isEmpty ||
            handJoints == Set(
                HumanHandPoseObservation.JointName.allCases
            )
        else {
            throw .incompleteHandJointVocabulary(chirality)
        }
    }
}
