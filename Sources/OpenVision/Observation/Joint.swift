public struct Joint: Sendable, Hashable {
    public let location: NormalizedPoint
    public let jointName: String
    public let confidence: Float

    public init(
        location: NormalizedPoint,
        jointName: String,
        confidence: Float
    ) throws(VisionError) {
        guard confidence.isFinite, (0 ... 1).contains(confidence) else {
            throw .invalidConfidence(confidence)
        }

        self.location = location
        self.jointName = jointName
        self.confidence = confidence
    }

    public func squaredDistance(to other: Joint) -> Float {
        let xDistance = location.x - other.location.x
        let yDistance = location.y - other.location.y
        return (xDistance * xDistance) + (yDistance * yDistance)
    }
}
