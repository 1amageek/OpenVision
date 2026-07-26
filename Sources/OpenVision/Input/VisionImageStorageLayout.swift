public enum VisionImageStorageLayout: Sendable, Hashable {
    case packed(bytesPerRow: Int, byteCount: Int)
    case planar([VisionImagePlaneLayout])
}
