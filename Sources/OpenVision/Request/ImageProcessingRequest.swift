import OpenCoreMedia

public protocol ImageProcessingRequest: VisionRequest {
    var regionOfInterest: NormalizedRect { get set }

    func perform(
        on sampleBuffer: any CMSampleBuffer,
        orientation: VisionImageOrientation?
    ) async throws(VisionError) -> Result

    func perform(
        on input: VisionImageInput
    ) async throws(VisionError) -> Result
}
