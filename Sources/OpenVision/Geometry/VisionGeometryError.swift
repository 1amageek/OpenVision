public enum VisionGeometryError: Error, Sendable, Equatable {
    case nonFiniteCoordinate
    case coordinateOutOfRange(x: Float, y: Float)
    case nonPositiveExtent(width: Float, height: Float)
    case rectangleOutOfRange(
        x: Float,
        y: Float,
        width: Float,
        height: Float
    )
}
