public protocol VisionRequest: Sendable, Hashable {
    associatedtype Result: Sendable

    var descriptor: RequestDescriptor { get }
    var computeDeviceSelections:
        [VisionComputeStage: VisionComputeDeviceID] { get }

    mutating func setComputeDevice(
        _ computeDevice: VisionComputeDeviceID?,
        for computeStage: VisionComputeStage
    )
}
