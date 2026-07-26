public struct VisionModelTensorDescriptor: Sendable, Hashable {
    public enum Dimension: Sendable, Hashable {
        case fixed(Int)
        case batch(maximum: Int)
    }

    public enum Axis: Sendable, Hashable {
        case x
        case y
    }

    public enum Meaning: Sendable, Hashable {
        case personDetections(maximumCount: Int)
        case classIndices(maximumCount: Int)
        case simCC(
            axis: Axis,
            jointCount: Int,
            splitRatio: Float
        )
    }

    public let id: VisionModelTensorID
    public let elementType: VisionModelInputDescriptor.ElementType
    public let shape: [Dimension]
    public let meaning: Meaning

    public init(
        id: VisionModelTensorID,
        elementType: VisionModelInputDescriptor.ElementType,
        shape: [Dimension],
        meaning: Meaning
    ) throws(VisionModelManifestError) {
        guard !id.rawValue.isEmpty else {
            throw .emptyTensorID
        }
        guard !shape.isEmpty else {
            throw .emptyTensorShape(id)
        }
        for dimension in shape {
            let value: Int
            switch dimension {
            case .fixed(let fixed):
                value = fixed
            case .batch(let maximum):
                value = maximum
            }
            guard value > 0 else {
                throw .invalidTensorDimension(id)
            }
        }

        switch meaning {
        case .personDetections(let maximumCount):
            guard maximumCount > 0 else {
                throw .invalidTensorMeaning(id)
            }
            guard
                shape.count == 3,
                case .batch = shape[0],
                case .fixed(maximumCount) = shape[1],
                case .fixed(5) = shape[2]
            else {
                throw .incompatibleTensorShape(id)
            }
        case .classIndices(let maximumCount):
            guard maximumCount > 0 else {
                throw .invalidTensorMeaning(id)
            }
            guard
                shape.count == 2,
                case .batch = shape[0],
                case .fixed(maximumCount) = shape[1]
            else {
                throw .incompatibleTensorShape(id)
            }
        case .simCC(_, let jointCount, let splitRatio):
            guard
                jointCount > 0,
                splitRatio.isFinite,
                splitRatio > 0
            else {
                throw .invalidTensorMeaning(id)
            }
            guard
                shape.count == 3,
                case .batch = shape[0],
                case .fixed(jointCount) = shape[1]
            else {
                throw .incompatibleTensorShape(id)
            }
        }

        self.id = id
        self.elementType = elementType
        self.shape = shape
        self.meaning = meaning
    }
}
