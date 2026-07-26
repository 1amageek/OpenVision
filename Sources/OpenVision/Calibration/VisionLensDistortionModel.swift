public enum VisionLensDistortionModel: Sendable, Hashable {
    case radialTangential(
        radialK1: Float,
        radialK2: Float,
        tangentialP1: Float,
        tangentialP2: Float,
        radialK3: Float
    )

    public init(
        radialK1: Float,
        radialK2: Float,
        tangentialP1: Float,
        tangentialP2: Float,
        radialK3: Float
    ) throws(VisionCalibrationError) {
        guard
            radialK1.isFinite,
            radialK2.isFinite,
            tangentialP1.isFinite,
            tangentialP2.isFinite,
            radialK3.isFinite
        else {
            throw .invalidLensDistortion
        }
        self = .radialTangential(
            radialK1: radialK1,
            radialK2: radialK2,
            tangentialP1: tangentialP1,
            tangentialP2: tangentialP2,
            radialK3: radialK3
        )
    }
}
