import OpenCoreMedia

public struct DetectHumanHandPoseRequest:
    ImageProcessingRequest
{
    public typealias Result = [HumanHandPoseObservation]

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
    public var maximumHandCount: Int
    public var regionOfInterest: NormalizedRect
    public private(set) var computeDeviceSelections:
        [VisionComputeStage: VisionComputeDeviceID]

    public var descriptor: RequestDescriptor {
        .detectHumanHandPoseRequest(revision)
    }

    public var supportedJointNames:
        [HumanHandPoseObservation.JointName]
    {
        HumanHandPoseObservation.JointName.allCases
    }

    public var supportedJointsGroupNames:
        [HumanHandPoseObservation.JointsGroupName]
    {
        HumanHandPoseObservation.JointsGroupName.allCases
    }

    public init(
        _ revision: Revision? = nil
    ) {
        self.revision = revision ?? .revision1
        maximumHandCount = 2
        regionOfInterest = .fullImage
        computeDeviceSelections = [:]
    }

    public mutating func setComputeDevice(
        _ computeDevice: VisionComputeDeviceID?,
        for computeStage: VisionComputeStage
    ) {
        computeDeviceSelections[computeStage] = computeDevice
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
        on input: VisionImageInput
    ) async throws(VisionError) -> Result {
        defer {
            input.releaseInput()
        }

        guard maximumHandCount > 0 else {
            throw .invalidProviderCapability("maximumHandCount")
        }

        let environment = try VisionContext.executionEnvironment()
        guard environment.capabilities.requests.contains(descriptor)
        else {
            throw .unsupportedRequest(descriptor)
        }
        let providerSession = environment.session

        guard environment.capabilities.pixelFormats.contains(
            input.pixelFormat
        ) else {
            throw .unsupportedPixelFormat(input.pixelFormat)
        }
        guard environment.capabilities.memoryDomains.contains(
            input.memoryDomain
        ) else {
            throw .unsupportedMemoryDomain(input.memoryDomain)
        }
        guard environment.capabilities.inputOwnershipModes.contains(
            input.ownershipMode
        ) else {
            throw .unsupportedInputOwnershipMode(
                input.ownershipMode
            )
        }
        for (computeStage, computeDevice) in computeDeviceSelections {
            guard environment.capabilities.supports(
                computeDevice,
                for: computeStage
            ) else {
                throw .unsupportedComputeDevice(computeDevice)
            }
        }

        let executionID = environment.executionSequence.next(
            sessionID: providerSession.descriptor.id
        )
        if Task.isCancelled {
            await providerSession.cancel(executionID)
            throw .cancelled(executionID)
        }

        return try await VisionProviderExecution.run(
            session: providerSession,
            executionID: executionID,
            operation: {
                () async throws(VisionError)
                    -> [HumanHandPoseObservation] in
                try await providerSession.handPoseObservations(
                    for: self,
                    input: input,
                    executionID: executionID
                )
            }
        )
    }
}
