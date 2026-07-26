import OpenVision
import Testing

@Suite("OpenVision image input contract")
struct OpenVisionImageInputContractTests {
    @Test("Packed layout and storage are immutable snapshots")
    func packedLayoutSnapshot() throws {
        let sample = try OpenVisionTestFixture.ownedSample()
        let pixelBuffer = try sample.imageBuffer()
        var sourceAddress: UInt?
        try pixelBuffer.withReadBytes { bytes in
            sourceAddress = bytes.withUnsafeBufferPointer {
                $0.baseAddress.map { UInt(bitPattern: $0) }
            }
        }

        let input = try VisionImageInput(sampleBuffer: sample)
        #expect(input.layout.dimensions.width == 2)
        #expect(input.layout.dimensions.height == 1)
        #expect(input.layout.pixelFormat == .bgra32)
        #expect(input.layout.planeCount == 0)
        #expect(input.layout.byteCount == 8)
        #expect(input.storage == .retainedHost)
        #expect(
            input.storage.transferModes.contains(
                .stagedHostToDevice(fullFrameCopyCount: 1)
            )
        )

        let borrowedAddress = try input.withReadBytes { bytes in
            bytes.withUnsafeBufferPointer {
                $0.baseAddress.map { UInt(bitPattern: $0) }
            }
        }
        #expect(borrowedAddress == sourceAddress)
    }

    @Test("Planar layout preserves per-plane dimensions and stride")
    func planarLayoutSnapshot() throws {
        let input = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.planarSample()
        )

        #expect(input.layout.isPlanar)
        #expect(input.layout.planeCount == 2)
        #expect(input.layout.byteCount == 12)
        let luma = try input.layout.plane(at: 0)
        let chroma = try input.layout.plane(at: 1)
        #expect(luma.dimensions.width == 4)
        #expect(luma.dimensions.height == 2)
        #expect(luma.bytesPerRow == 4)
        #expect(luma.byteCount == 8)
        #expect(chroma.dimensions.width == 2)
        #expect(chroma.dimensions.height == 1)
        #expect(chroma.bytesPerRow == 4)
        #expect(chroma.byteCount == 4)

        let lumaByteCount = try input.withReadBytes(
            ofPlane: 0
        ) { bytes in
            bytes.count
        }
        let chromaByteCount = try input.withReadBytes(
            ofPlane: 1
        ) { bytes in
            bytes.count
        }
        #expect(lumaByteCount == 8)
        #expect(chromaByteCount == 4)
    }

    @Test("Storage descriptor rejects transfer without required access")
    func storageTransferAccessValidation() {
        #expect(throws: VisionImageStorageError.missingAccess(
            .nativeResource,
            transferMode: .importedExternalMemory
        )) {
            _ = try VisionImageStorageDescriptor(
                memoryDomain: .external,
                ownershipMode: .imported,
                accessModes: [.hostBytes],
                transferModes: [.importedExternalMemory]
            )
        }

        #expect(throws: VisionImageStorageError.invalidFullFrameCopyCount(0)) {
            _ = try VisionImageStorageDescriptor(
                memoryDomain: .host,
                ownershipMode: .retained,
                accessModes: [.hostBytes],
                transferModes: [
                    .stagedHostToDevice(fullFrameCopyCount: 0)
                ]
            )
        }
    }

    @Test("Layout rejects undersized and discontinuous storage")
    func layoutValidation() throws {
        let dimensions = try CVPixelDimensions(width: 2, height: 2)

        #expect(throws: VisionImageLayoutError.invalidByteCount(7)) {
            _ = try VisionImageLayout(
                dimensions: dimensions,
                pixelFormat: .bgra32,
                storage: .packed(
                    bytesPerRow: 4,
                    byteCount: 7
                )
            )
        }

        let plane = try VisionImagePlaneLayout(
            index: 1,
            dimensions: dimensions,
            bytesPerRow: 2,
            byteCount: 4
        )
        #expect(throws: VisionImageLayoutError.nonContiguousPlaneIndex(
            expected: 0,
            actual: 1
        )) {
            _ = try VisionImageLayout(
                dimensions: dimensions,
                pixelFormat: .grayscale8,
                storage: .planar([plane])
            )
        }
    }

    @Test("Sample-buffer input cannot advertise an unavailable native resource")
    func unavailableNativeResource() throws {
        let nativeStorage = try VisionImageStorageDescriptor(
            memoryDomain: .external,
            ownershipMode: .imported,
            accessModes: [.nativeResource],
            transferModes: [.importedExternalMemory]
        )

        #expect(throws: VisionError.unsupportedImageStorageAccess(
            .hostBytes
        )) {
            _ = try VisionImageInput(
                sampleBuffer: OpenVisionTestFixture.ownedSample(),
                storage: nativeStorage
            )
        }
    }

    @Test("Borrow body failure remains typed")
    func borrowFailure() throws {
        let input = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample()
        )
        let expected = VisionError.resourceExhausted(
            resource: "test-transfer"
        )

        #expect(throws: expected) {
            _ = try input.withReadBytes { _ throws(VisionError) -> Int in
                throw expected
            }
        }
    }

    @Test("Selected staged transfer must be supported by provider and input")
    func selectedTransferValidation() async throws {
        let model = try OpenVisionTestFixture.model()
        let staged = VisionTransferMode.stagedHostToDevice(
            fullFrameCopyCount: 1
        )
        let provider = try OpenVisionTestProvider(
            id: "staged-provider",
            model: model,
            transferModes: [staged]
        )
        let stagedSample = try OpenVisionTestFixture.ownedSample()
        let observations = try await VisionContext.withProvider(
            provider,
            configuration: VisionSessionConfiguration(
                model: model,
                transferMode: staged
            ),
            operation: {
                () async throws(VisionError)
                    -> [HumanBodyPoseObservation] in
                try await DetectHumanBodyPoseRequest().perform(
                    on: stagedSample
                )
            }
        )
        #expect(observations.count == 1)

        let retainedOnly = try VisionImageStorageDescriptor(
            memoryDomain: .host,
            ownershipMode: .retained,
            accessModes: [.hostBytes],
            transferModes: [.retainedHostAccess]
        )
        let input = try VisionImageInput(
            sampleBuffer: OpenVisionTestFixture.ownedSample(),
            storage: retainedOnly
        )

        await #expect(throws: VisionError.inputTransferModeUnavailable(
            requested: staged,
            available: [.retainedHostAccess]
        )) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model,
                    transferMode: staged
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: input
                    )
                }
            )
        }
    }

    @Test("Unsupported configured transfer fails before session creation")
    func unsupportedConfiguredTransfer() async throws {
        let model = try OpenVisionTestFixture.model()
        let state = OpenVisionTestState()
        let provider = try OpenVisionTestProvider(
            id: "retained-provider",
            model: model,
            state: state
        )
        let staged = VisionTransferMode.stagedHostToDevice(
            fullFrameCopyCount: 1
        )
        let sample = try OpenVisionTestFixture.ownedSample()

        await #expect(throws: VisionError.unsupportedTransferMode(staged)) {
            _ = try await VisionContext.withProvider(
                provider,
                configuration: VisionSessionConfiguration(
                    model: model,
                    transferMode: staged
                ),
                operation: {
                    () async throws(VisionError)
                        -> [HumanBodyPoseObservation] in
                    try await DetectHumanBodyPoseRequest().perform(
                        on: sample
                    )
                }
            )
        }
        #expect(state.snapshot().makeSessionCount == 0)
        #expect(state.snapshot().shutdownCount == 0)
    }
}
