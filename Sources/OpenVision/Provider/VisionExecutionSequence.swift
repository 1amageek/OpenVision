import Synchronization

final class VisionExecutionSequence: Sendable {
    private let state: Mutex<UInt64>

    init(initialValue: UInt64 = 0) {
        state = Mutex(initialValue)
    }

    func next(
        sessionID: VisionProviderSessionID
    ) throws(VisionError) -> VisionExecutionID {
        try state.withLock { value throws(VisionError) in
            let (nextValue, overflow) = value.addingReportingOverflow(1)
            guard !overflow else {
                throw .resourceExhausted(
                    resource: "visionExecutionSequence"
                )
            }
            value = nextValue
            return VisionExecutionID(
                sessionID: sessionID,
                sequence: value
            )
        }
    }
}
