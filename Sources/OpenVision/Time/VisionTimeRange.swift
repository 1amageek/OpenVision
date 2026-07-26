import OpenCoreMedia

public struct VisionTimeRange: Sendable, Hashable {
    public let range: CMTimeRange
    public let clockDomain: VisionClockDomain

    public init(
        range: CMTimeRange,
        clockDomain: VisionClockDomain
    ) throws(VisionTemporalError) {
        guard
            range.isValid,
            !range.isIndefinite,
            range.start.isNumeric,
            range.duration.isNumeric
        else {
            throw .invalidTimeRange(range)
        }
        self.range = range
        self.clockDomain = clockDomain
    }

    public func contains(
        _ timestamp: VisionTimestamp
    ) throws(VisionTemporalError) -> Bool {
        guard timestamp.clockDomain == clockDomain else {
            throw .incompatibleClockDomain(
                expected: clockDomain,
                actual: timestamp.clockDomain
            )
        }
        return range.containsTime(timestamp.time)
    }
}
