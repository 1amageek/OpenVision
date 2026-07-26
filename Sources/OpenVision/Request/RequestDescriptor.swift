public enum RequestDescriptor: Sendable, Hashable {
    case detectHumanBodyPoseRequest(
        DetectHumanBodyPoseRequest.Revision
    )
    case detectHumanHandPoseRequest(
        DetectHumanHandPoseRequest.Revision
    )
}
