import OpenCoreVideo

public struct VisionModelInputDescriptor: Sendable, Hashable {
    public enum ResizePolicy: Sendable, Hashable {
        case scaleFill
        case scaleFit
        case centerCrop
    }

    public enum Normalization: Sendable, Hashable {
        case zeroToOne
        case negativeOneToOne
        case affine(scale: Float, bias: Float)
    }

    public let width: Int
    public let height: Int
    public let pixelFormat: CVPixelFormatType
    public let resizePolicy: ResizePolicy
    public let normalization: Normalization

    public init(
        width: Int,
        height: Int,
        pixelFormat: CVPixelFormatType,
        resizePolicy: ResizePolicy,
        normalization: Normalization
    ) throws(VisionError) {
        guard width > 0, height > 0 else {
            throw .invalidProviderCapability(
                "modelInputDimensions"
            )
        }

        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.resizePolicy = resizePolicy
        self.normalization = normalization
    }
}
