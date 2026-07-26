public protocol HumanHandPoseProviderSession:
    Sendable
{
    func handPoseObservations(
        for request: DetectHumanHandPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanHandPoseObservation]
}

extension HumanHandPoseProviderSession {
    public func handPoseObservations(
        for request: DetectHumanHandPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanHandPoseObservation] {
        throw .unsupportedRequest(request.descriptor)
    }
}
