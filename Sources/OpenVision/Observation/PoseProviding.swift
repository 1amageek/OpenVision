public protocol PoseProviding {
    associatedtype PoseJointName:
        RawRepresentable,
        Sendable,
        Hashable
    where PoseJointName.RawValue == String

    associatedtype PoseJointsGroupName:
        RawRepresentable,
        CaseIterable,
        Sendable,
        Hashable
    where PoseJointsGroupName.RawValue == String

    var availableJointNames: [PoseJointName] { get }
    var availableJointsGroupNames: [PoseJointsGroupName] { get }

    func joint(for jointName: PoseJointName) -> Joint?
    func allJoints(
        in groupName: PoseJointsGroupName?
    ) -> [PoseJointName: Joint]
}
