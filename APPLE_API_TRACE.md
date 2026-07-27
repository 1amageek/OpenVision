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
| `RequestDescriptor` | Same name | Body pose, hand pose, and stateful body-pose tracking cases | Unsupported families are absent |
| `ComputeStage` / `MLComputeDevice` | `VisionComputeStage` / `VisionComputeDeviceID` | Implemented | No Core ML dependency |
| Core ML request/model configuration | `VisionModelManifest` | Portable extension | Explicit stage graph, tensor semantics, preprocessing, provenance, and quality contract for TensorRT/Metal parity |
| `request.perform(on:)` | Same operation shape | Implemented | Provider is injected by `VisionContext` |
| `UUID` observation identity | `VisionObservationID` | Implemented | Two portable `UInt64` words |
| `StatefulRequest` | `StatefulRequest` | Implemented contract | Requires explicit reset and shutdown in addition to Apple properties |
| `TrackObjectRequest` | `TrackHumanBodyPoseRequest` | Portable extension, not API equivalence | Tracks compact pose geometry after provider inference; it does not track arbitrary rectangles |
| Tracking, flow, segmentation, text | Body-pose tracking only | Partial | Unimplemented families remain absent rather than returning successful stubs |

The local Apple interface exposes provider selection internally. OpenVision's
provider is public because portable deployments must select TensorRT, Metal, or
another implementation explicitly.

`TrackHumanBodyPoseRequest` follows Apple's stateful-request lifecycle and
timestamp-spacing shape, but is intentionally an OpenVision extension. Apple
`TrackObjectRequest` begins from a `DetectedObjectObservation`; OpenVision's
first temporal slice performs the existing body-pose request and associates
only bounded joint metadata. The provider still receives the ordinary body-pose
descriptor, so CUDA, TensorRT, Metal, and model artifacts remain outside the
portable tracking state machine.
