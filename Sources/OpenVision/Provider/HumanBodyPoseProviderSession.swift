public protocol HumanBodyPoseProviderSession:
    Sendable
{
    func bodyPoseObservations(
        for request: DetectHumanBodyPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanBodyPoseObservation]
}

extension HumanBodyPoseProviderSession {
    public func bodyPoseObservations(
        for request: DetectHumanBodyPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanBodyPoseObservation] {
        throw .unsupportedRequest(request.descriptor)
    }
}
