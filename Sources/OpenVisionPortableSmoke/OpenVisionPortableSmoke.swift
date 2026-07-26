import OpenVision

@main
enum OpenVisionPortableSmoke {
    static func main() {
        do {
            let point = try NormalizedPoint(x: 0.5, y: 0.5)
            let joint = try Joint(
                location: point,
                jointName: HumanBodyPoseObservation.JointName.nose.rawValue,
                confidence: 1
            )
            precondition(joint.location == point)
            precondition(
                DetectHumanBodyPoseRequest().descriptor ==
                    .detectHumanBodyPoseRequest(.revision2)
            )
        } catch {
            fatalError("OpenVision portable smoke failed")
        }
    }
}
