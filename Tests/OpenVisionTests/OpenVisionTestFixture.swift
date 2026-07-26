import OpenVision
import Synchronization

final class OpenVisionTestState: Sendable {
    struct Snapshot: Sendable {
        var makeSessionCount = 0
        var executionCount = 0
        var cancellationCount = 0
        var shutdownCount = 0
        var consumedInputCount = 0
        var borrowedAddress: UInt?
    }

    private let state = Mutex(Snapshot())

    func recordSession() {
        state.withLock { $0.makeSessionCount += 1 }
    }

    func recordExecution() {
        state.withLock { $0.executionCount += 1 }
    }

    func recordCancellation() {
        state.withLock { $0.cancellationCount += 1 }
    }

    func recordShutdown() {
        state.withLock { $0.shutdownCount += 1 }
    }

    func recordInputConsumption(address: UInt?) {
        state.withLock {
            $0.consumedInputCount += 1
            $0.borrowedAddress = address
        }
    }

    func snapshot() -> Snapshot {
        state.withLock { $0 }
    }
}

actor OpenVisionTestInferenceGate {
    private var arrived = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func suspendAfterInputConsumption() async {
        arrived = true
        let waiters = arrivalWaiters
        arrivalWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }

        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitForArrival() async {
        if arrived {
            return
        }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

struct OpenVisionTestProvider: VisionProvider {
    enum Behavior: Sendable {
        case success
        case executionFailure(VisionError)
    }

    let descriptor: VisionProviderDescriptor
    let capabilities: VisionProviderCapabilities
    let model: VisionModelDescriptor
    let state: OpenVisionTestState
    let observationMarker: UInt64
    let behavior: Behavior
    let shutdownFailure: VisionError?
    let inferenceGate: OpenVisionTestInferenceGate?

    init(
        id: String,
        model: VisionModelDescriptor,
        pixelFormats: Set<CVPixelFormatType> = [.bgra32],
        memoryDomains: Set<VisionMemoryDomain> = [.host],
        inputOwnershipModes: Set<VisionInputOwnershipMode> = [.retained],
        observationMarker: UInt64 = 1,
        behavior: Behavior = .success,
        shutdownFailure: VisionError? = nil,
        inferenceGate: OpenVisionTestInferenceGate? = nil,
        state: OpenVisionTestState = OpenVisionTestState()
    ) throws(VisionError) {
        descriptor = VisionProviderDescriptor(
            id: VisionProviderID(rawValue: id),
            revision: "test-1"
        )
        capabilities = try VisionProviderCapabilities(
            requests: [
                .detectHumanBodyPoseRequest(.revision2),
                .detectHumanHandPoseRequest(.revision1)
            ],
            pixelFormats: pixelFormats,
            memoryDomains: memoryDomains,
            inputOwnershipModes: inputOwnershipModes,
            transferModes: [.retainedHostAccess],
            computeDevices: [
                .main: [VisionComputeDeviceID(rawValue: "test")]
            ],
            maximumInFlightRequestCount: 1
        )
        self.model = model
        self.state = state
        self.observationMarker = observationMarker
        self.behavior = behavior
        self.shutdownFailure = shutdownFailure
        self.inferenceGate = inferenceGate
    }

    func makeSession(
        configuration: VisionSessionConfiguration
    ) async throws(VisionError) -> any VisionProviderSession {
        guard configuration.model == model else {
            throw .modelUnavailable(configuration.model)
        }
        state.recordSession()
        return OpenVisionTestProviderSession(
            descriptor: VisionProviderSessionDescriptor(
                id: VisionProviderSessionID(
                    high: observationMarker,
                    low: 1
                ),
                provider: descriptor,
                model: model
            ),
            state: state,
            observationMarker: observationMarker,
            behavior: behavior,
            shutdownFailure: shutdownFailure,
            inferenceGate: inferenceGate
        )
    }
}

actor OpenVisionTestProviderSession:
    VisionProviderSession
{
    nonisolated let descriptor: VisionProviderSessionDescriptor

    private let state: OpenVisionTestState
    private let observationMarker: UInt64
    private let behavior: OpenVisionTestProvider.Behavior
    private let shutdownFailure: VisionError?
    private let inferenceGate: OpenVisionTestInferenceGate?
    private var isShutDown = false
    private var activeExecutionID: VisionExecutionID?
    private var cancelledExecutionIDs: Set<VisionExecutionID> = []

    init(
        descriptor: VisionProviderSessionDescriptor,
        state: OpenVisionTestState,
        observationMarker: UInt64,
        behavior: OpenVisionTestProvider.Behavior,
        shutdownFailure: VisionError?,
        inferenceGate: OpenVisionTestInferenceGate?
    ) {
        self.descriptor = descriptor
        self.state = state
        self.observationMarker = observationMarker
        self.behavior = behavior
        self.shutdownFailure = shutdownFailure
        self.inferenceGate = inferenceGate
    }

    func bodyPoseObservations(
        for request: DetectHumanBodyPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanBodyPoseObservation] {
        try begin(executionID)
        defer {
            activeExecutionID = nil
        }
        state.recordExecution()

        var borrowedAddress: UInt?
        try input.withReadBytes { bytes in
            borrowedAddress = bytes.withUnsafeBufferPointer {
                $0.baseAddress.map { UInt(bitPattern: $0) }
            }
        }
        _ = input.releaseInput()
        state.recordInputConsumption(address: borrowedAddress)

        if let inferenceGate {
            await inferenceGate.suspendAfterInputConsumption()
        }
        try failureIfConfigured()

        let point: NormalizedPoint
        do {
            point = try NormalizedPoint(x: 0.5, y: 0.25)
        } catch let error {
            throw .invalidGeometry(error)
        }
        let joint = try Joint(
            location: point,
            jointName:
                HumanBodyPoseObservation.JointName.nose.rawValue,
            confidence: 0.9
        )
        let timeRange = CMTimeRange(
            start: input.timing.presentationTimeStamp,
            duration: input.timing.duration
        )
        let observation = try HumanBodyPoseObservation(
            id: VisionObservationID(
                high: observationMarker,
                low: executionID.sequence
            ),
            confidence: 0.9,
            timeRange: timeRange,
            originatingRequestDescriptor: request.descriptor,
            joints: [.nose: joint]
        )
        return [observation]
    }

    func handPoseObservations(
        for request: DetectHumanHandPoseRequest,
        input: VisionImageInput,
        executionID: VisionExecutionID
    ) async throws(VisionError) -> [HumanHandPoseObservation] {
        try begin(executionID)
        defer {
            activeExecutionID = nil
        }
        state.recordExecution()
        _ = input.releaseInput()
        state.recordInputConsumption(address: nil)
        try failureIfConfigured()

        let point: NormalizedPoint
        do {
            point = try NormalizedPoint(x: 0.4, y: 0.6)
        } catch let error {
            throw .invalidGeometry(error)
        }
        let joint = try Joint(
            location: point,
            jointName:
                HumanHandPoseObservation.JointName.indexTip.rawValue,
            confidence: 0.8
        )
        let observation = try HumanHandPoseObservation(
            id: VisionObservationID(
                high: observationMarker,
                low: executionID.sequence
            ),
            confidence: 0.8,
            timeRange: CMTimeRange(
                start: input.timing.presentationTimeStamp,
                duration: input.timing.duration
            ),
            originatingRequestDescriptor: request.descriptor,
            chirality: .right,
            joints: [.indexTip: joint]
        )
        return [observation]
    }

    func cancel(_ executionID: VisionExecutionID) async {
        guard cancelledExecutionIDs.insert(executionID).inserted else {
            return
        }
        if activeExecutionID == executionID {
            activeExecutionID = nil
        }
        state.recordCancellation()
        if let inferenceGate {
            await inferenceGate.release()
        }
    }

    func shutdown() async throws(VisionError) {
        state.recordShutdown()
        if let shutdownFailure {
            throw shutdownFailure
        }
        isShutDown = true
        activeExecutionID = nil
    }

    private func begin(
        _ executionID: VisionExecutionID
    ) throws(VisionError) {
        guard !isShutDown else {
            throw .sessionShutDown(descriptor.id)
        }
        guard activeExecutionID == nil else {
            throw .providerBusy(descriptor.provider.id)
        }
        activeExecutionID = executionID
    }

    private func failureIfConfigured() throws(VisionError) {
        if case .executionFailure(let error) = behavior {
            throw error
        }
    }
}

final class OpenVisionReleaseCounter: Sendable {
    private let countState = Mutex<Int>(0)

    var count: Int {
        countState.withLock { $0 }
    }

    func record() {
        countState.withLock { $0 += 1 }
    }
}

enum OpenVisionTestFixture {
    static func model(
        request: RequestDescriptor =
            .detectHumanBodyPoseRequest(.revision2)
    ) throws(VisionError) -> VisionModelDescriptor {
        VisionModelDescriptor(
            id: "test-pose",
            revision: "1",
            request: request,
            input: try VisionModelInputDescriptor(
                width: 2,
                height: 1,
                pixelFormat: .bgra32,
                resizePolicy: .scaleFit,
                normalization: .zeroToOne
            ),
            outputSchemaRevision: "test-joints-1"
        )
    }

    static func ownedSample(
        pixelFormat: CVPixelFormatType = .bgra32
    ) throws -> CMImageSampleBuffer {
        let dimensions = try CVPixelDimensions(width: 2, height: 1)
        let pixelBuffer = try CVPackedPixelBuffer(
            dimensions: dimensions,
            pixelFormat: pixelFormat,
            bytesPerPixel: 4,
            bytesPerRow: 8
        )
        return try CMImageSampleBuffer(
            imageBuffer: pixelBuffer,
            formatDescription: CMImmutableVideoFormatDescription(
                dimensions: dimensions,
                pixelFormat: pixelFormat
            ),
            timing: CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMTime(
                    value: 10,
                    timescale: 30
                ),
                decodeTimeStamp: .invalid
            )
        )
    }

    static func externalSample(
        releaseCounter: OpenVisionReleaseCounter
    ) throws -> (
        sample: CMImageSampleBuffer,
        address: UInt
    ) {
        let byteCount = 8
        let baseAddress = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: 8
        )
        baseAddress.initializeMemory(
            as: UInt8.self,
            repeating: 7,
            count: byteCount
        )
        let storage = try CVExternalPixelBufferStorage(
            baseAddress: baseAddress,
            byteCount: byteCount,
            accessCapabilities: [.read]
        ) { address, _ in
            address.deallocate()
            releaseCounter.record()
        }
        let dimensions = try CVPixelDimensions(width: 2, height: 1)
        let layout = try CVPackedPixelBufferLayout(
            dimensions: dimensions,
            pixelFormat: .bgra32,
            bytesPerPixel: 4,
            bytesPerRow: byteCount
        )
        let pixelBuffer = try CVPackedPixelBuffer(
            layout: layout,
            storage: storage
        )
        let sample = try CMImageSampleBuffer(
            imageBuffer: pixelBuffer,
            formatDescription: CMImmutableVideoFormatDescription(
                dimensions: dimensions,
                pixelFormat: .bgra32
            ),
            timing: CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: .zero,
                decodeTimeStamp: .invalid
            )
        )
        return (sample, UInt(bitPattern: baseAddress))
    }
}
