public protocol VisionProviderSession:
    HumanBodyPoseProviderSession,
    HumanHandPoseProviderSession
{
    var descriptor: VisionProviderSessionDescriptor { get }

    /// Requests cancellation for one submitted execution.
    ///
    /// Implementations must be idempotent for the same execution identifier.
    /// The request path can issue an early cancellation to interrupt backend
    /// work and repeat it while awaiting ordered cancellation completion.
    func cancel(
        _ executionID: VisionExecutionID
    ) async

    func shutdown() async throws(VisionError)
}
