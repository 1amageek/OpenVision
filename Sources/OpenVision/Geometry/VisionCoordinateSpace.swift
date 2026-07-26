public struct VisionCoordinateSpace: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case sourcePixels
        case normalizedImage
        case displayPixels
        case cameraRelative3D
    }

    public enum Units: Sendable, Hashable {
        case normalized
        case pixels
        case meters
    }

    public enum Handedness: Sendable, Hashable {
        case notApplicable
        case leftHanded
        case rightHanded
    }

    public enum Dimensionality: Sendable, Hashable {
        case two
        case three
    }

    public enum AxisDirection: Sendable, Hashable {
        case left
        case right
        case up
        case down
        case forward
        case backward
        case notApplicable
    }

    public let id: VisionCoordinateSpaceID
    public let source: String?
    public let kind: Kind
    public let units: Units
    public let origin: CoordinateOrigin?
    public let handedness: Handedness
    public let dimensionality: Dimensionality
    public let xAxis: AxisDirection
    public let yAxis: AxisDirection
    public let zAxis: AxisDirection

    public init(
        id: VisionCoordinateSpaceID,
        source: String?,
        kind: Kind,
        units: Units,
        origin: CoordinateOrigin?,
        handedness: Handedness,
        dimensionality: Dimensionality,
        xAxis: AxisDirection,
        yAxis: AxisDirection,
        zAxis: AxisDirection
    ) {
        self.id = id
        self.source = source
        self.kind = kind
        self.units = units
        self.origin = origin
        self.handedness = handedness
        self.dimensionality = dimensionality
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.zAxis = zAxis
    }

    public static func sourcePixels(
        source: String?
    ) -> Self {
        let sourceComponent = source.map { "source.\($0)" } ?? "none"
        return Self(
            id: VisionCoordinateSpaceID(
                rawValue: "openvision.source-pixels.\(sourceComponent)"
            ),
            source: source,
            kind: .sourcePixels,
            units: .pixels,
            origin: .upperLeft,
            handedness: .notApplicable,
            dimensionality: .two,
            xAxis: .right,
            yAxis: .down,
            zAxis: .notApplicable
        )
    }

    public static func normalizedImage(
        source: String?
    ) -> Self {
        let sourceComponent = source.map { "source.\($0)" } ?? "none"
        return Self(
            id: VisionCoordinateSpaceID(
                rawValue: "openvision.normalized-image.\(sourceComponent)"
            ),
            source: source,
            kind: .normalizedImage,
            units: .normalized,
            origin: .lowerLeft,
            handedness: .notApplicable,
            dimensionality: .two,
            xAxis: .right,
            yAxis: .up,
            zAxis: .notApplicable
        )
    }
}
