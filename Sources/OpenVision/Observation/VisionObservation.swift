import OpenCoreMedia

public protocol VisionObservation: Sendable, Hashable {
    var id: VisionObservationID { get }
    var confidence: Float { get }
    var timeRange: CMTimeRange? { get }
    var originatingRequestDescriptor: RequestDescriptor? { get }
    var provenance: VisionObservationProvenance { get }
}
