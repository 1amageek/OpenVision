public enum VisionTransferMode: Sendable, Hashable {
    case directDeviceAccess
    case importedExternalMemory
    case retainedHostAccess
    case stagedHostToDevice(fullFrameCopyCount: Int)
}
