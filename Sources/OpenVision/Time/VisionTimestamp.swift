import OpenCoreMedia

public struct VisionTimestamp: Sendable, Hashable {
    public let time: CMTime
    public let clockDomain: VisionClockDomain

    public init(
        time: CMTime,
        clockDomain: VisionClockDomain
    ) throws(VisionTemporalError) {
        guard time.isNumeric, time.timescale > 0 else {
            throw .invalidTimestamp(time)
        }
        self.time = time
        self.clockDomain = clockDomain
    }
}
