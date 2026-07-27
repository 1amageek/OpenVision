public struct TrackedHumanBodyPoseObservation: Sendable, Hashable {
    public let pose: HumanBodyPoseObservation
    public let track: VisionTrackReference

    public init(
        pose: HumanBodyPoseObservation,
        track: VisionTrackReference
    ) {
        self.pose = pose
        self.track = track
    }
}
