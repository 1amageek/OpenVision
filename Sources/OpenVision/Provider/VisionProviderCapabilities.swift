import OpenCoreVideo

public struct VisionProviderCapabilities: Sendable, Hashable {
    public let requests: Set<RequestDescriptor>
    public let pixelFormats: Set<CVPixelFormatType>
    public let memoryDomains: Set<VisionMemoryDomain>
    public let inputOwnershipModes: Set<VisionInputOwnershipMode>
    public let transferModes: Set<VisionTransferMode>
    public let computeDevices:
        [VisionComputeStage: Set<VisionComputeDeviceID>]
    public let maximumInFlightRequestCount: Int

    public init(
        requests: Set<RequestDescriptor>,
        pixelFormats: Set<CVPixelFormatType>,
        memoryDomains: Set<VisionMemoryDomain>,
        inputOwnershipModes: Set<VisionInputOwnershipMode>,
        transferModes: Set<VisionTransferMode>,
        computeDevices:
            [VisionComputeStage: Set<VisionComputeDeviceID>],
        maximumInFlightRequestCount: Int
    ) throws(VisionError) {
        guard maximumInFlightRequestCount > 0 else {
            throw .invalidProviderCapability(
                "maximumInFlightRequestCount"
            )
        }
        guard !requests.isEmpty else {
            throw .invalidProviderCapability("requests")
        }
        guard !pixelFormats.isEmpty else {
            throw .invalidProviderCapability("pixelFormats")
        }
        guard !memoryDomains.isEmpty else {
            throw .invalidProviderCapability("memoryDomains")
        }
        guard !inputOwnershipModes.isEmpty else {
            throw .invalidProviderCapability("inputOwnershipModes")
        }
        guard !transferModes.isEmpty else {
            throw .invalidProviderCapability("transferModes")
        }
        for transferMode in transferModes {
            if case .stagedHostToDevice(let copyCount) = transferMode,
               copyCount <= 0 {
                throw .invalidProviderCapability(
                    "stagedHostToDevice.fullFrameCopyCount"
                )
            }
        }

        self.requests = requests
        self.pixelFormats = pixelFormats
        self.memoryDomains = memoryDomains
        self.inputOwnershipModes = inputOwnershipModes
        self.transferModes = transferModes
        self.computeDevices = computeDevices
        self.maximumInFlightRequestCount =
            maximumInFlightRequestCount
    }

    public func supports(
        _ computeDevice: VisionComputeDeviceID,
        for computeStage: VisionComputeStage
    ) -> Bool {
        computeDevices[computeStage]?.contains(computeDevice) == true
    }
}
