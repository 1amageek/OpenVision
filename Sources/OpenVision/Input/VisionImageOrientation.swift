public enum VisionImageOrientation:
    UInt32,
    Sendable,
    Hashable,
    CaseIterable
{
    case up = 1
    case upMirrored = 2
    case down = 3
    case downMirrored = 4
    case leftMirrored = 5
    case right = 6
    case rightMirrored = 7
    case left = 8
}
