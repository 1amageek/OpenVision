enum VisionInputValidation {
    static func validate(
        _ input: VisionImageInput,
        request: RequestDescriptor,
        computeDeviceSelections:
            [VisionComputeStage: VisionComputeDeviceID],
        environment: VisionContext.Environment
    ) throws(VisionError) {
        let capabilities = environment.capabilities

        guard capabilities.requests.contains(request) else {
            throw .unsupportedRequest(request)
        }
        guard capabilities.pixelFormats.contains(input.pixelFormat) else {
            throw .unsupportedPixelFormat(input.pixelFormat)
        }
        guard capabilities.memoryDomains.contains(
            input.storage.memoryDomain
        ) else {
            throw .unsupportedMemoryDomain(input.storage.memoryDomain)
        }
        guard capabilities.inputOwnershipModes.contains(
            input.storage.ownershipMode
        ) else {
            throw .unsupportedInputOwnershipMode(
                input.storage.ownershipMode
            )
        }

        let transferMode = environment.configuration.transferMode
        guard capabilities.transferModes.contains(transferMode) else {
            throw .unsupportedTransferMode(transferMode)
        }
        guard input.storage.transferModes.contains(transferMode) else {
            throw .inputTransferModeUnavailable(
                requested: transferMode,
                available: input.storage.transferModes
            )
        }

        for (computeStage, computeDevice) in computeDeviceSelections {
            guard capabilities.supports(
                computeDevice,
                for: computeStage
            ) else {
                throw .unsupportedComputeDevice(computeDevice)
            }
        }
    }
}
