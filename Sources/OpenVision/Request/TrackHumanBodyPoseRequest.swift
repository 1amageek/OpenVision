import OpenCoreMedia
import Synchronization

public final class TrackHumanBodyPoseRequest:
    StatefulRequest,
    ImageProcessingRequest
{
    private struct ConfigurationState: Sendable {
        var detectsHands: Bool
        var regionOfInterest: NormalizedRect
        var computeDeviceSelections:
            [VisionComputeStage: VisionComputeDeviceID]
    }

    public typealias Result = HumanBodyPoseTrackingUpdate

    public enum Revision:
        Int,
        Sendable,
        Hashable,
        Comparable
    {
        case revision1 = 1

        public static func < (
            lhs: Revision,
            rhs: Revision
        ) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public static let supportedRevisions: [Revision] = [
        .revision1
    ]

    public let revision: Revision
    public let trackingSessionID: VisionTrackingSessionID
    public let frameAnalysisSpacing: CMTime
    public let minimumLatencyFrameCount = 1
    public let maximumMissedAnalysisCount: Int
    public let maximumTrackCount: Int
    public let maximumNormalizedJointDistance: Float

    private let configurationState: Mutex<ConfigurationState>
    private let trackingState: HumanBodyPoseTrackingState

    public var descriptor: RequestDescriptor {
        .trackHumanBodyPoseRequest(revision)
    }

    public var detectsHands: Bool {
        get {
            configurationState.withLock { $0.detectsHands }
        }
        set {
            configurationState.withLock { $0.detectsHands = newValue }
        }
    }

    public var regionOfInterest: NormalizedRect {
        get {
            configurationState.withLock { $0.regionOfInterest }
        }
        set {
            configurationState.withLock {
                $0.regionOfInterest = newValue
            }
        }
    }

    public var computeDeviceSelections:
        [VisionComputeStage: VisionComputeDeviceID]
    {
        configurationState.withLock { $0.computeDeviceSelections }
    }

    public init(
        trackingSessionID: VisionTrackingSessionID,
        _ revision: Revision? = nil,
        frameAnalysisSpacing: CMTime = .zero,
        maximumMissedAnalysisCount: Int = 2,
        maximumTrackCount: Int = 4,
        maximumNormalizedJointDistance: Float = 0.15
    ) throws(VisionTrackingError) {
        guard
            frameAnalysisSpacing.isNumeric,
            frameAnalysisSpacing >= .zero
        else {
            throw .invalidFrameAnalysisSpacing(frameAnalysisSpacing)
        }
        guard
            maximumMissedAnalysisCount >= 0,
            maximumMissedAnalysisCount < Int.max
        else {
            throw .invalidMaximumMissedAnalysisCount(
                maximumMissedAnalysisCount
            )
        }
        guard maximumTrackCount > 0 else {
            throw .invalidMaximumTrackCount(maximumTrackCount)
        }
        guard
            maximumNormalizedJointDistance.isFinite,
            maximumNormalizedJointDistance > 0,
            maximumNormalizedJointDistance <= 2
        else {
            throw .invalidMaximumNormalizedJointDistance(
                maximumNormalizedJointDistance
            )
        }

        self.revision = revision ?? .revision1
        self.trackingSessionID = trackingSessionID
        self.frameAnalysisSpacing = frameAnalysisSpacing
        self.maximumMissedAnalysisCount =
            maximumMissedAnalysisCount
        self.maximumTrackCount = maximumTrackCount
        self.maximumNormalizedJointDistance =
            maximumNormalizedJointDistance
        configurationState = Mutex(
            ConfigurationState(
                detectsHands: false,
                regionOfInterest: .fullImage,
                computeDeviceSelections: [:]
            )
        )
        trackingState = HumanBodyPoseTrackingState(
            sessionID: trackingSessionID
        )
    }

    public func setComputeDevice(
        _ computeDevice: VisionComputeDeviceID?,
        for computeStage: VisionComputeStage
    ) {
        configurationState.withLock {
            $0.computeDeviceSelections[computeStage] = computeDevice
        }
    }

    public func perform(
        on sampleBuffer: any CMSampleBuffer,
        orientation: VisionImageOrientation? = nil
    ) async throws(VisionError) -> Result {
        let input = try VisionImageInput(
            sampleBuffer: sampleBuffer,
            orientation: orientation ?? .up
        )
        return try await perform(on: input)
    }

    public func perform(
        on sampleBuffer: any CMSampleBuffer,
        orientation: VisionImageOrientation? = nil,
        frameID: VisionFrameID,
        clockDomain: VisionClockDomain
    ) async throws(VisionError) -> Result {
        let input = try VisionImageInput(
            sampleBuffer: sampleBuffer,
            orientation: orientation ?? .up,
            frameID: frameID,
            clockDomain: clockDomain
        )
        return try await perform(on: input)
    }

    public func perform(
        on input: VisionImageInput
    ) async throws(VisionError) -> Result {
        defer {
            input.releaseInput()
        }

        let configuration = configurationState.withLock { $0 }
        var poseRequest = DetectHumanBodyPoseRequest(.revision2)
        poseRequest.detectsHands = configuration.detectsHands
        poseRequest.regionOfInterest = configuration.regionOfInterest
        for (stage, device) in configuration.computeDeviceSelections {
            poseRequest.setComputeDevice(device, for: stage)
        }
        return try await trackingState.process(
            input: input,
            poseRequest: poseRequest,
            frameAnalysisSpacing: frameAnalysisSpacing,
            maximumMissedAnalysisCount:
                maximumMissedAnalysisCount,
            maximumTrackCount: maximumTrackCount,
            maximumNormalizedJointDistance:
                maximumNormalizedJointDistance
        )
    }

    @discardableResult
    public func reset() async throws(VisionError) -> UInt64 {
        try await trackingState.reset()
    }

    public func shutdown() async throws(VisionError) {
        try await trackingState.shutdown()
    }

    public static func == (
        lhs: TrackHumanBodyPoseRequest,
        rhs: TrackHumanBodyPoseRequest
    ) -> Bool {
        lhs.trackingSessionID == rhs.trackingSessionID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(trackingSessionID)
    }
}
