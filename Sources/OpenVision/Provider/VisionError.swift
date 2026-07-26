import OpenCoreMedia
import OpenCoreVideo

public indirect enum VisionError: Error, Sendable, Equatable {
    case providerNotConfigured
    case unsupportedRequest(RequestDescriptor)
    case unsupportedRevision(RequestDescriptor)
    case unsupportedPixelFormat(CVPixelFormatType)
    case unsupportedMemoryDomain(VisionMemoryDomain)
    case unsupportedInputOwnershipMode(VisionInputOwnershipMode)
    case unsupportedImageStorageAccess(VisionImageStorageAccess)
    case unsupportedTransferMode(VisionTransferMode)
    case inputTransferModeUnavailable(
        requested: VisionTransferMode,
        available: Set<VisionTransferMode>
    )
    case unsupportedComputeDevice(VisionComputeDeviceID)
    case invalidSampleBuffer(CMSampleBufferError)
    case invalidPixelBuffer(CVPixelBufferError)
    case invalidImageLayout(VisionImageLayoutError)
    case invalidImageStorage(VisionImageStorageError)
    case invalidImageAccessInvocationCount(Int)
    case imageAccessFailure(operation: String)
    case inputReleased
    case temporal(VisionTemporalError)
    case coordinate(VisionCoordinateError)
    case calibration(VisionCalibrationError)
    case invalidGeometry(VisionGeometryError)
    case invalidConfidence(Float)
    case jointNameMismatch(expected: String, actual: String)
    case invalidProviderCapability(String)
    case modelUnavailable(VisionModelDescriptor)
    case modelIncompatible(VisionModelDescriptor)
    case providerBusy(VisionProviderID)
    case cancelled(VisionExecutionID)
    case sessionShutDown(VisionProviderSessionID)
    case resourceExhausted(resource: String)
    case backend(VisionBackendFailure)
    case operationAndCleanup(
        operation: VisionError,
        cleanup: VisionError
    )
}
