import Synchronization

final class VisionExecutionSequence: Sendable {
    private let state = Mutex<UInt64>(0)

    func next(
        sessionID: VisionProviderSessionID
    ) -> VisionExecutionID {
        state.withLock { value in
            value &+= 1
            return VisionExecutionID(
                sessionID: sessionID,
                sequence: value
            )
        }
    }
}
