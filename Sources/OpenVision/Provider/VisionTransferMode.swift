public enum VisionTransferMode: Sendable, Hashable {
    case directDeviceAccess
    case importedExternalMemory
    case retainedHostAccess
    case stagedHostToDevice(fullFrameCopyCount: Int)

    public var fullFrameCopyCount: Int {
        switch self {
        case .directDeviceAccess,
             .importedExternalMemory,
             .retainedHostAccess:
            return 0
        case .stagedHostToDevice(let copyCount):
            return copyCount
        }
    }

    var requiredStorageAccess: VisionImageStorageAccess {
        switch self {
        case .retainedHostAccess,
             .stagedHostToDevice:
            return .hostBytes
        case .directDeviceAccess,
             .importedExternalMemory:
            return .nativeResource
        }
    }
}
