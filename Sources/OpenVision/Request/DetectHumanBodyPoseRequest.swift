import OpenCoreMedia

public struct DetectHumanBodyPoseRequest:
    ImageProcessingRequest
{
    public typealias Result = [HumanBodyPoseObservation]

    public enum Revision:
        Int,
        Sendable,
        Hashable,
        Comparable
    {
        case revision2 = 2

        public static func < (
            lhs: Revision,
            rhs: Revision
        ) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public static let supportedRevisions: [Revision] = [
        .revision2
    ]

    public let revision: Revision
    public var detectsHands: Bool
    public var regionOfInterest: NormalizedRect
    public private(set) var computeDeviceSelections:
        [VisionComputeStage: VisionComputeDeviceID]

    public var descriptor: RequestDescriptor {
        .detectHumanBodyPoseRequest(revision)
    }

    public var supportedJointNames:
        [HumanBodyPoseObservation.JointName]
    {
        HumanBodyPoseObservation.JointName.allCases
    }

    public var supportedJointsGroupNames:
        [HumanBodyPoseObservation.JointsGroupName]
    {
        HumanBodyPoseObservation.JointsGroupName.allCases
    }

    public init(
        _ revision: Revision? = nil
    ) {
        self.revision = revision ?? .revision2
        detectsHands = false
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
                    -> [HumanBodyPoseObservation] in
                try await providerSession.bodyPoseObservations(
                    for: self,
                    input: input,
                    executionID: executionID
                )
            }
        )
    }
}
