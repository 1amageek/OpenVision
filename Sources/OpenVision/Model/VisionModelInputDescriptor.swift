public struct VisionModelInputDescriptor: Sendable, Hashable {
    public enum ResizePolicy: Sendable, Hashable {
        case scaleFill
        case scaleFit
        case centerCrop
        case regionAffine
    }

    public enum OrientationPolicy: Sendable, Hashable {
        case canonicalUpright
    }

    public enum TransferFunction: Sendable, Hashable {
        case linear
        case sRGB
    }

    public enum ElementType: Sendable, Hashable {
        case float32
        case float16
        case int8
        case int32
        case int64
    }

    public struct RGBValues: Sendable, Hashable {
        public let red: Float
        public let green: Float
        public let blue: Float

        public init(
            red: Float,
            green: Float,
            blue: Float
        ) throws(VisionModelManifestError) {
            guard red.isFinite, green.isFinite, blue.isFinite else {
                throw .invalidInputValue("rgbValues")
            }
            self.red = red
            self.green = green
            self.blue = blue
        }

        fileprivate init(
            validatedRed red: Float,
            green: Float,
            blue: Float
        ) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public static let zero = Self(
            validatedRed: 0,
            green: 0,
            blue: 0
        )
        public static let one = Self(
            validatedRed: 1,
            green: 1,
            blue: 1
        )
    }

    public struct Normalization: Sendable, Hashable {
        public let scale: RGBValues
        public let bias: RGBValues

        public init(
            scale: RGBValues,
            bias: RGBValues
        ) {
            self.scale = scale
            self.bias = bias
        }

        public static let zeroToOne = Self(
            scale: .one,
            bias: .zero
        )

        public static let negativeOneToOne = Self(
            scale: RGBValues(
                validatedRed: 2,
                green: 2,
                blue: 2
            ),
            bias: RGBValues(
                validatedRed: -1,
                green: -1,
                blue: -1
            )
        )

        public static func affine(
            scale: Float,
            bias: Float
        ) throws(VisionModelManifestError) -> Self {
            try channelwiseAffine(
                redScale: scale,
                greenScale: scale,
                blueScale: scale,
                redBias: bias,
                greenBias: bias,
                blueBias: bias
            )
        }

        public static func channelwiseAffine(
            redScale: Float,
            greenScale: Float,
            blueScale: Float,
            redBias: Float,
            greenBias: Float,
            blueBias: Float
        ) throws(VisionModelManifestError) -> Self {
            Self(
                scale: try RGBValues(
                    red: redScale,
                    green: greenScale,
                    blue: blueScale
                ),
                bias: try RGBValues(
                    red: redBias,
                    green: greenBias,
                    blue: blueBias
                )
            )
        }
    }

    public enum Source: Sendable, Hashable {
        case image
        case regions(
            stage: VisionModelStageID,
            tensor: VisionModelTensorID,
            minimumConfidence: Float,
            maximumCount: Int,
            scale: Float
        )
    }

    public let width: Int
    public let height: Int
    public let source: Source
    public let resizePolicy: ResizePolicy
    public let orientationPolicy: OrientationPolicy
    public let transferFunction: TransferFunction
    public let tensorLayout: VisionTensorLayout
    public let channelOrder: VisionTensorChannelOrder
    public let elementType: ElementType
    public let letterboxColor: RGBValues
    public let normalization: Normalization

    public init(
        width: Int,
        height: Int,
        source: Source,
        resizePolicy: ResizePolicy,
        orientationPolicy: OrientationPolicy = .canonicalUpright,
        transferFunction: TransferFunction,
        tensorLayout: VisionTensorLayout,
        channelOrder: VisionTensorChannelOrder,
        elementType: ElementType,
        letterboxColor: RGBValues = .zero,
        normalization: Normalization
    ) throws(VisionModelManifestError) {
        guard width > 0, height > 0 else {
            throw .invalidInputDimensions(
                width: width,
                height: height
            )
        }
        guard
            (0 ... 1).contains(letterboxColor.red),
            (0 ... 1).contains(letterboxColor.green),
            (0 ... 1).contains(letterboxColor.blue)
        else {
            throw .invalidInputValue("letterboxColor")
        }
        if case .regions(
            let stage,
            let tensor,
            let minimumConfidence,
            let maximumCount,
            let scale
        ) = source {
            guard !stage.rawValue.isEmpty else {
                throw .invalidRegionSource(stage)
            }
            guard !tensor.rawValue.isEmpty else {
                throw .emptyTensorID
            }
            guard
                minimumConfidence.isFinite,
                (0 ... 1).contains(minimumConfidence)
            else {
                throw .invalidInputValue(
                    "regionMinimumConfidence"
                )
            }
            guard maximumCount > 0 else {
                throw .invalidInputValue("regionMaximumCount")
            }
            guard scale.isFinite, scale > 0 else {
                throw .invalidInputValue("regionScale")
            }
        }
        switch (source, resizePolicy) {
        case (.regions, .regionAffine):
            break
        case (.regions, _):
            throw .regionSourceRequiresRegionAffine
        case (.image, .regionAffine):
            throw .regionAffineRequiresRegionSource
        case (.image, _):
            break
        }

        self.width = width
        self.height = height
        self.source = source
        self.resizePolicy = resizePolicy
        self.orientationPolicy = orientationPolicy
        self.transferFunction = transferFunction
        self.tensorLayout = tensorLayout
        self.channelOrder = channelOrder
        self.elementType = elementType
        self.letterboxColor = letterboxColor
        self.normalization = normalization
    }
}
