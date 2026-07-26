# Apple Vision API Trace

Evidence baseline:

- Xcode 27.0 beta
- macOS 27.0 SDK
- `Vision.swiftmodule/arm64e-apple-macos.swiftinterface`
- Apple documentation read with `remark`

| Apple API | OpenVision API | Status | Portable difference |
|---|---|---|---|
| `VisionRequest` | `VisionRequest` | Implemented slice | Backend-neutral compute IDs |
| `ImageProcessingRequest` | `ImageProcessingRequest` | Implemented for sample buffers and owned inputs | URL, Data, CGImage, and CIImage inputs not declared |
| `DetectHumanBodyPoseRequest` | Same name | Implemented contract | Provider supplies behavior |
| `DetectHumanHandPoseRequest` | Same name | Implemented contract | Provider supplies behavior |
| `HumanBodyPoseObservation` | Same name | Implemented 2D joints and hands | Portable observation ID |
| `HumanHandPoseObservation` | Same name | Implemented 2D joints and chirality | Portable observation ID |
| `NormalizedPoint` / `NormalizedRect` | Same names | Implemented | `Float`; throwing validation |
| `RequestDescriptor` | Same name | Body and hand cases only | Unsupported families are absent |
| `ComputeStage` / `MLComputeDevice` | `VisionComputeStage` / `VisionComputeDeviceID` | Implemented | No Core ML dependency |
| `request.perform(on:)` | Same operation shape | Implemented | Provider is injected by `VisionContext` |
| `UUID` observation identity | `VisionObservationID` | Implemented | Two portable `UInt64` words |
| `StatefulRequest` | Not declared | Pending | Requires ordered temporal-state contract |
| Tracking, flow, segmentation, text | Not declared | Pending | No successful stubs |

The local Apple interface exposes provider selection internally. OpenVision's
provider is public because portable deployments must select TensorRT, Metal, or
another implementation explicitly.
