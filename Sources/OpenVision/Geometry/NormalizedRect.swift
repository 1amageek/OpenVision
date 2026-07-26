public struct NormalizedRect: Sendable, Hashable {
    public let origin: NormalizedPoint
    public let width: Float
    public let height: Float

    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float
    ) throws(VisionGeometryError) {
        guard width.isFinite, height.isFinite else {
            throw .nonFiniteCoordinate
        }
        guard width > 0, height > 0 else {
            throw .nonPositiveExtent(width: width, height: height)
        }
        let origin = try NormalizedPoint(x: x, y: y)
        let maximumX = x.addingProduct(1, width)
        let maximumY = y.addingProduct(1, height)
        guard maximumX <= 1, maximumY <= 1 else {
            throw .rectangleOutOfRange(
                x: x,
                y: y,
                width: width,
                height: height
            )
        }

        self.origin = origin
        self.width = width
        self.height = height
    }

    private init(
        validatedOrigin origin: NormalizedPoint,
        validatedWidth width: Float,
        validatedHeight height: Float
    ) {
        self.origin = origin
        self.width = width
        self.height = height
    }

    public static let fullImage = NormalizedRect(
        validatedOrigin: .zero,
        validatedWidth: 1,
        validatedHeight: 1
    )
}
