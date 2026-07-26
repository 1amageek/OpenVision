public struct VisionPoint2D: Sendable, Hashable {
    public let x: Float
    public let y: Float

    public init(
        x: Float,
        y: Float
    ) throws(VisionCoordinateError) {
        guard x.isFinite, y.isFinite else {
            throw .nonFiniteCoordinate
        }
        self.x = x
        self.y = y
    }
}
