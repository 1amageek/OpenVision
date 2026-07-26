public struct VisionSessionConfiguration: Sendable, Hashable {
    public let model: VisionModelManifest
    public let transferMode: VisionTransferMode
    public let computeDevices:
        [VisionComputeStage: VisionComputeDeviceID]

    public init(
        model: VisionModelManifest,
        transferMode: VisionTransferMode = .retainedHostAccess,
        computeDevices:
            [VisionComputeStage: VisionComputeDeviceID] = [:]
    ) {
        self.model = model
        self.transferMode = transferMode
        self.computeDevices = computeDevices
    }
}
