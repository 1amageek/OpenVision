public struct VisionVector3: Sendable, Hashable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(
        x: Float,
        y: Float,
        z: Float
    ) throws(VisionCoordinateError) {
        guard x.isFinite, y.isFinite, z.isFinite else {
            throw .nonFiniteTransform
        }
        self.x = x
        self.y = y
        self.z = z
    }

    init(
        uncheckedX x: Float,
        y: Float,
        z: Float
    ) {
        self.x = x
        self.y = y
        self.z = z
    }
}
