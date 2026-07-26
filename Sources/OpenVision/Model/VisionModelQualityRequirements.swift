public struct VisionModelQualityRequirements: Sendable, Hashable {
    public let permittedPrecisions: Set<VisionModelPrecision>
    public let maximumEndToEndLatencyMilliseconds: Double
    public let maximumPersonCount: Int

    public init(
        permittedPrecisions: Set<VisionModelPrecision>,
        maximumEndToEndLatencyMilliseconds: Double,
        maximumPersonCount: Int
    ) throws(VisionModelManifestError) {
        guard !permittedPrecisions.isEmpty else {
            throw .emptyPrecisionSet
        }
        guard
            maximumEndToEndLatencyMilliseconds.isFinite,
            maximumEndToEndLatencyMilliseconds > 0
        else {
            throw .invalidLatencyBudget(
                maximumEndToEndLatencyMilliseconds
            )
        }
        guard maximumPersonCount > 0 else {
            throw .invalidMaximumPersonCount(maximumPersonCount)
        }

        self.permittedPrecisions = permittedPrecisions
        self.maximumEndToEndLatencyMilliseconds =
            maximumEndToEndLatencyMilliseconds
        self.maximumPersonCount = maximumPersonCount
    }
}
