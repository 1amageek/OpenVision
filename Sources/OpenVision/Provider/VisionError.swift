import OpenCoreMedia
import OpenCoreVideo

public indirect enum VisionError: Error, Sendable, Equatable {
    case providerNotConfigured
    case unsupportedRequest(RequestDescriptor)
    case unsupportedRevision(RequestDescriptor)
    case unsupportedPixelFormat(CVPixelFormatType)
    case unsupportedMemoryDomain(VisionMemoryDomain)
    case unsupportedInputOwnershipMode(VisionInputOwnershipMode)
    case unsupportedComputeDevice(VisionComputeDeviceID)
    case invalidSampleBuffer(CMSampleBufferError)
    case invalidPixelBuffer(CVPixelBufferError)
    case inputReleased
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
