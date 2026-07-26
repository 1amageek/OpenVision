public struct NormalizedPoint: Sendable, Hashable {
    public let x: Float
    public let y: Float

    public init(
        x: Float,
        y: Float
    ) throws(VisionGeometryError) {
        guard x.isFinite, y.isFinite else {
            throw .nonFiniteCoordinate
        }
        guard (0 ... 1).contains(x), (0 ... 1).contains(y) else {
            throw .coordinateOutOfRange(x: x, y: y)
        }

        self.x = x
        self.y = y
    }

    private init(
        validatedX x: Float,
        validatedY y: Float
    ) {
        self.x = x
        self.y = y
    }

    public static let zero = NormalizedPoint(
        validatedX: 0,
        validatedY: 0
    )
}
