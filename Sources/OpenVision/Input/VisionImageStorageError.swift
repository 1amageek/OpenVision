public enum VisionImageStorageError: Error, Sendable, Equatable {
    case emptyAccessModes
    case emptyTransferModes
    case invalidFullFrameCopyCount(Int)
    case missingAccess(
        VisionImageStorageAccess,
        transferMode: VisionTransferMode
    )
}
