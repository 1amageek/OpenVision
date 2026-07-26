@testable import OpenVision
import Testing

@Suite("Vision execution sequence")
struct VisionExecutionSequenceTests {
    @Test("Sequence exhaustion is a typed failure and never wraps")
    func sequenceExhaustion() throws {
        let sequence = VisionExecutionSequence(
            initialValue: UInt64.max - 1
        )
        let sessionID = VisionProviderSessionID(high: 1, low: 1)

        let last = try sequence.next(sessionID: sessionID)
        #expect(last.sequence == UInt64.max)
        #expect(throws: VisionError.resourceExhausted(
            resource: "visionExecutionSequence"
        )) {
            _ = try sequence.next(sessionID: sessionID)
        }
    }
}
