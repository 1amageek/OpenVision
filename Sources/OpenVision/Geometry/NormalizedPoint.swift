import OpenCoreVideo

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

    public init(
        imagePoint: VisionPoint2D,
        in imageSize: CVPixelDimensions,
        origin: CoordinateOrigin = .lowerLeft
    ) throws(VisionGeometryError) {
        let normalizedX = imagePoint.x / Float(imageSize.width)
        let imageY = imagePoint.y / Float(imageSize.height)
        let normalizedY: Float
        switch origin {
        case .lowerLeft:
            normalizedY = imageY
        case .upperLeft:
            normalizedY = 1 - imageY
        }
        try self.init(x: normalizedX, y: normalizedY)
    }

    public func toImageCoordinates(
        _ imageSize: CVPixelDimensions,
        origin: CoordinateOrigin = .lowerLeft
    ) throws(VisionCoordinateError) -> VisionPoint2D {
        let imageY: Float
        switch origin {
        case .lowerLeft:
            imageY = y
        case .upperLeft:
            imageY = 1 - y
        }
        return try VisionPoint2D(
            x: x * Float(imageSize.width),
            y: imageY * Float(imageSize.height)
        )
    }

    public func toImageCoordinates(
        from regionOfInterest: NormalizedRect,
        imageSize: CVPixelDimensions,
        origin: CoordinateOrigin = .lowerLeft
    ) throws(VisionCoordinateError) -> VisionPoint2D {
        let fullImagePoint = NormalizedPoint(
            validatedX:
                regionOfInterest.origin.x + x * regionOfInterest.width,
            validatedY:
                regionOfInterest.origin.y + y * regionOfInterest.height
        )
        return try fullImagePoint.toImageCoordinates(
            imageSize,
            origin: origin
        )
    }

    public func verticallyFlipped() -> NormalizedPoint {
        NormalizedPoint(
            validatedX: x,
            validatedY: 1 - y
        )
    }
}
