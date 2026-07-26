public struct VisionMatrix3x3: Sendable, Hashable {
    public let row0: VisionVector3
    public let row1: VisionVector3
    public let row2: VisionVector3

    public init(
        row0: VisionVector3,
        row1: VisionVector3,
        row2: VisionVector3
    ) {
        self.row0 = row0
        self.row1 = row1
        self.row2 = row2
    }

    public static let identity = Self(
        row0: VisionVector3(uncheckedX: 1, y: 0, z: 0),
        row1: VisionVector3(uncheckedX: 0, y: 1, z: 0),
        row2: VisionVector3(uncheckedX: 0, y: 0, z: 1)
    )
}
