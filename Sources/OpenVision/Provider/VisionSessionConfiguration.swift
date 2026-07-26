public struct VisionSessionConfiguration: Sendable, Hashable {
    public let model: VisionModelDescriptor
    public let computeDevices:
        [VisionComputeStage: VisionComputeDeviceID]

    public init(
        model: VisionModelDescriptor,
        computeDevices:
            [VisionComputeStage: VisionComputeDeviceID] = [:]
    ) {
        self.model = model
        self.computeDevices = computeDevices
    }
}
