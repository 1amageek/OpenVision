public struct VisionImageStorageDescriptor: Sendable, Hashable {
    public let memoryDomain: VisionMemoryDomain
    public let ownershipMode: VisionInputOwnershipMode
    public let accessModes: Set<VisionImageStorageAccess>
    public let transferModes: Set<VisionTransferMode>

    public init(
        memoryDomain: VisionMemoryDomain,
        ownershipMode: VisionInputOwnershipMode,
        accessModes: Set<VisionImageStorageAccess>,
        transferModes: Set<VisionTransferMode>
    ) throws(VisionImageStorageError) {
        guard !accessModes.isEmpty else {
            throw .emptyAccessModes
        }
        guard !transferModes.isEmpty else {
            throw .emptyTransferModes
        }
        for transferMode in transferModes {
            if case .stagedHostToDevice(let copyCount) = transferMode,
               copyCount <= 0 {
                throw .invalidFullFrameCopyCount(copyCount)
            }
            let requiredAccess = transferMode.requiredStorageAccess
            guard accessModes.contains(requiredAccess) else {
                throw .missingAccess(
                    requiredAccess,
                    transferMode: transferMode
                )
            }
        }

        self.memoryDomain = memoryDomain
        self.ownershipMode = ownershipMode
        self.accessModes = accessModes
        self.transferModes = transferModes
    }

    public static let retainedHost = makeRetainedHost()

    // The pinned Swift 6.4 regular-WASI optimizer miscompiles Set allocation
    // in a global initializer. Keep only this small descriptor construction
    // unoptimized; frame access and transfer validation remain optimized.
    @_optimize(none)
    private static func makeRetainedHost() -> Self {
        Self(
            validatedMemoryDomain: .host,
            ownershipMode: .retained,
            accessModes: [.hostBytes],
            transferModes: [
                .retainedHostAccess,
                .stagedHostToDevice(fullFrameCopyCount: 1)
            ]
        )
    }

    private init(
        validatedMemoryDomain memoryDomain: VisionMemoryDomain,
        ownershipMode: VisionInputOwnershipMode,
        accessModes: Set<VisionImageStorageAccess>,
        transferModes: Set<VisionTransferMode>
    ) {
        self.memoryDomain = memoryDomain
        self.ownershipMode = ownershipMode
        self.accessModes = accessModes
        self.transferModes = transferModes
    }
}
