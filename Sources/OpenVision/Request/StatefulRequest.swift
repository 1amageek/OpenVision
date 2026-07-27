import OpenCoreMedia

public protocol StatefulRequest: VisionRequest {
    var minimumLatencyFrameCount: Int { get }
    var frameAnalysisSpacing: CMTime { get }
}
