import Testing
@testable import OpenVision

@Suite("Semantic model manifest")
struct VisionModelManifestTests {
    @Test("Valid manifest preserves semantic stage contracts")
    func validManifest() throws {
        let manifest = try OpenVisionTestFixture.model()
        let stageID = VisionModelStageID(rawValue: "pose")
        let stage = manifest.stage(identifiedBy: stageID)

        #expect(manifest.request ==
            .detectHumanBodyPoseRequest(.revision2))
        #expect(stage?.input.width == 2)
        #expect(stage?.input.tensorLayout == .channelsFirst)
        #expect(stage?.input.channelOrder == .rgb)
        #expect(manifest.output.jointMappings.count == 19)
        #expect(manifest.quality.permittedPrecisions == [.float32])
    }

    @Test("Region source must be a compatible detector stage")
    func incompatibleRegionStage() throws {
        let manifest = try OpenVisionTestFixture.model()
        let template = try #require(manifest.stages.first)
        let detectionsID =
            VisionModelTensorID(rawValue: "detections")
        let detectorID =
            VisionModelStageID(rawValue: "not-a-detector")
        let fakeDetections = try VisionModelTensorDescriptor(
            id: detectionsID,
            elementType: .float32,
            shape: [
                .batch(maximum: 1),
                .fixed(1),
                .fixed(5)
            ],
            meaning: .personDetections(maximumCount: 1)
        )
        let producer = try VisionModelStageDescriptor(
            id: detectorID,
            operation: .humanWholeBodyPose,
            input: template.input,
            outputs: [fakeDetections],
            provenance: template.provenance
        )
        let consumerInput = try VisionModelInputDescriptor(
            width: template.input.width,
            height: template.input.height,
            source: .regions(
                stage: detectorID,
                tensor: detectionsID,
                minimumConfidence: 0.3,
                maximumCount: 1,
                scale: 1.25
            ),
            resizePolicy: .regionAffine,
            transferFunction: .sRGB,
            tensorLayout: .channelsFirst,
            channelOrder: .rgb,
            elementType: .float32,
            normalization: .zeroToOne
        )
        let consumer = try VisionModelStageDescriptor(
            id: template.id,
            operation: template.operation,
            input: consumerInput,
            outputs: template.outputs,
            provenance: template.provenance
        )

        #expect(
            throws:
                VisionModelManifestError
                    .incompatibleRegionStage(detectorID)
        ) {
            _ = try VisionModelManifest(
                id: manifest.id,
                revision: manifest.revision,
                request: manifest.request,
                stages: [producer, consumer],
                output: manifest.output,
                quality: manifest.quality
            )
        }
    }

    @Test("Duplicate stage identity fails explicitly")
    func duplicateStage() throws {
        let manifest = try OpenVisionTestFixture.model()
        let stage = try #require(manifest.stages.first)

        #expect(
            throws: VisionModelManifestError.duplicateStageID(
                stage.id
            )
        ) {
            _ = try VisionModelManifest(
                id: manifest.id,
                revision: manifest.revision,
                request: manifest.request,
                stages: [stage, stage],
                output: manifest.output,
                quality: manifest.quality
            )
        }
    }

    @Test("Region source must resolve to an earlier detection stage")
    func missingRegionSource() throws {
        let manifest = try OpenVisionTestFixture.model()
        let template = try #require(manifest.stages.first)
        let missingStage = VisionModelStageID(rawValue: "missing")
        let input = try VisionModelInputDescriptor(
            width: template.input.width,
            height: template.input.height,
            source: .regions(
                stage: missingStage,
                tensor: VisionModelTensorID(rawValue: "detections"),
                minimumConfidence: 0.3,
                maximumCount: 1,
                scale: 1.25
            ),
            resizePolicy: .regionAffine,
            transferFunction: .sRGB,
            tensorLayout: .channelsFirst,
            channelOrder: .rgb,
            elementType: .float32,
            normalization: .zeroToOne
        )
        let consumer = try VisionModelStageDescriptor(
            id: template.id,
            operation: template.operation,
            input: input,
            outputs: template.outputs,
            provenance: template.provenance
        )

        #expect(
            throws:
                VisionModelManifestError.invalidRegionSource(
                    missingStage
                )
        ) {
            _ = try VisionModelManifest(
                id: manifest.id,
                revision: manifest.revision,
                request: manifest.request,
                stages: [consumer],
                output: manifest.output,
                quality: manifest.quality
            )
        }
    }

    @Test("Region source and affine resize are one semantic contract")
    func regionAffineContract() throws {
        let manifest = try OpenVisionTestFixture.model()
        let template = try #require(manifest.stages.first)

        #expect(
            throws:
                VisionModelManifestError
                    .regionAffineRequiresRegionSource
        ) {
            _ = try VisionModelInputDescriptor(
                width: 2,
                height: 2,
                source: .image,
                resizePolicy: .regionAffine,
                transferFunction: .sRGB,
                tensorLayout: .channelsFirst,
                channelOrder: .rgb,
                elementType: .float32,
                normalization: .zeroToOne
            )
        }
        #expect(
            throws:
                VisionModelManifestError
                    .regionSourceRequiresRegionAffine
        ) {
            _ = try VisionModelInputDescriptor(
                width: 2,
                height: 2,
                source: .regions(
                    stage: template.id,
                    tensor:
                        VisionModelTensorID(rawValue: "detections"),
                    minimumConfidence: 0.3,
                    maximumCount: 1,
                    scale: 1.25
                ),
                resizePolicy: .scaleFit,
                transferFunction: .sRGB,
                tensorLayout: .channelsFirst,
                channelOrder: .rgb,
                elementType: .float32,
                normalization: .zeroToOne
            )
        }
    }

    @Test("SimCC tensor shape must match input dimensions")
    func simCCShapeMismatch() throws {
        let manifest = try OpenVisionTestFixture.model()
        let template = try #require(manifest.stages.first)
        let xTensor = try #require(
            template.output(
                identifiedBy: manifest.output.xDistribution
            )
        )
        let invalidY = try VisionModelTensorDescriptor(
            id: manifest.output.yDistribution,
            elementType: .float32,
            shape: [
                .batch(maximum: 1),
                .fixed(133),
                .fixed(3)
            ],
            meaning: .simCC(
                axis: .y,
                jointCount: 133,
                splitRatio: 2
            )
        )
        let stage = try VisionModelStageDescriptor(
            id: template.id,
            operation: template.operation,
            input: template.input,
            outputs: [xTensor, invalidY],
            provenance: template.provenance
        )

        #expect(
            throws:
                VisionModelManifestError.incompatibleOutputTensor(
                    stage: stage.id,
                    tensor: xTensor.id
                )
        ) {
            _ = try VisionModelManifest(
                id: manifest.id,
                revision: manifest.revision,
                request: manifest.request,
                stages: [stage],
                output: manifest.output,
                quality: manifest.quality
            )
        }
    }

    @Test("Body request requires the complete public joint vocabulary")
    func incompleteBodyVocabulary() throws {
        let manifest = try OpenVisionTestFixture.model()
        let mapping = try VisionPoseJointMapping(
            target: .body(.nose),
            source: .index(0)
        )
        let output = try VisionModelOutputDescriptor(
            schemaRevision: manifest.output.schemaRevision,
            stage: manifest.output.stage,
            xDistribution: manifest.output.xDistribution,
            yDistribution: manifest.output.yDistribution,
            jointMappings: [mapping],
            minimumJointConfidence:
                manifest.output.minimumJointConfidence,
            coordinateTransform:
                manifest.output.coordinateTransform
        )

        #expect(
            throws:
                VisionModelManifestError
                    .incompleteBodyJointVocabulary
        ) {
            _ = try VisionModelManifest(
                id: manifest.id,
                revision: manifest.revision,
                request: manifest.request,
                stages: manifest.stages,
                output: output,
                quality: manifest.quality
            )
        }
    }

    @Test("Hand request supports an unattributed complete vocabulary")
    func handVocabulary() throws {
        let manifest = try OpenVisionTestFixture.model()
        let mappings = try HumanHandPoseObservation.JointName
            .allCases.enumerated().map { index, joint in
                try VisionPoseJointMapping(
                    target: .hand(
                        chirality: nil,
                        joint: joint
                    ),
                    source: .index(index)
                )
            }
        let output = try VisionModelOutputDescriptor(
            schemaRevision: "hand-1",
            stage: manifest.output.stage,
            xDistribution: manifest.output.xDistribution,
            yDistribution: manifest.output.yDistribution,
            jointMappings: mappings,
            minimumJointConfidence: 0.1,
            coordinateTransform:
                .modelInputPixelsUpperLeftToNormalizedImageLowerLeft
        )
        let templateStage = try #require(manifest.stages.first)
        let handStage = try VisionModelStageDescriptor(
            id: templateStage.id,
            operation: .humanHandPose,
            input: templateStage.input,
            outputs: templateStage.outputs,
            provenance: templateStage.provenance
        )
        let handManifest = try VisionModelManifest(
            id: "fixture-hand",
            revision: "1",
            request: .detectHumanHandPoseRequest(.revision1),
            stages: [handStage],
            output: output,
            quality: manifest.quality
        )

        #expect(handManifest.output.jointMappings.count == 21)
    }

    @Test("Digest and channel normalization reject non-finite input")
    func invalidScalarEvidence() {
        #expect(
            throws: VisionModelManifestError.invalidSHA256Digest(
                "not-a-digest"
            )
        ) {
            _ = try VisionModelProvenance.SHA256Digest(
                hexadecimal: "not-a-digest"
            )
        }
        let nonASCIIDigest = String(repeating: "١", count: 64)
        #expect(
            throws: VisionModelManifestError.invalidSHA256Digest(
                nonASCIIDigest
            )
        ) {
            _ = try VisionModelProvenance.SHA256Digest(
                hexadecimal: nonASCIIDigest
            )
        }
        #expect(
            throws: VisionModelManifestError.invalidInputValue(
                "rgbValues"
            )
        ) {
            _ = try VisionModelInputDescriptor.Normalization
                .channelwiseAffine(
                    redScale: .infinity,
                    greenScale: 1,
                    blueScale: 1,
                    redBias: 0,
                    greenBias: 0,
                    blueBias: 0
                )
        }
    }
}
