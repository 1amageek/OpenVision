# OpenVision Design

## Dependency boundary

`OpenVision` owns portable visual request and observation semantics.
`OpenVisionTensorRT` and future providers import OpenVision and conform through
public API. The composition root selects a provider.

```text
OpenVisionTensorRT ----> OpenVision ----> OpenCoreMedia
                             |
                             +----------> OpenCoreVideo
```

Camera capture and GPU inference are independent. A V4L2 camera driver does not
become an OpenVision provider, and OpenVision does not import a camera driver.

## Execution

`VisionContext.withProvider` creates a session and stores an immutable
environment in `TaskLocal` storage. Nested scopes restore the previous value.
Each environment owns a `Mutex<UInt64>` execution sequence. The same storage and
isolation contract compiles on Native, WASM, and Embedded.

`VisionProviderSession` is the Embedded-compatible composition of lifecycle,
body-pose, and hand-pose provider protocols. Request dispatch is static
existential dispatch; no runtime cast or reflection is required.

Provider capability checking occurs before execution. The session method still
returns a typed unsupported error if called directly for an unimplemented
family. Capability mismatch never becomes a successful empty observation.
Compute-device support is checked for the selected execution stage; support on
an unrelated stage does not authorize execution.

Request execution installs a task-cancellation handler around the provider
call. Cancellation is forwarded to the active provider execution identifier
and then rechecked before returning an observation. Provider cancellation is
required to be idempotent because cancellation can race normal completion and
session cleanup.

## Input ownership and copies

`VisionImageInput` snapshots small immutable metadata and owns one optional
sample-buffer reference behind `Mutex<State>`. A byte borrow copies only the
reference under the lock, then performs the external callback after releasing
the lock.

```text
Metadata lane
  CVPixelBuffer
    -> VisionImageLayout
       dimensions + format + packed/planar stride and extent

Ownership lane
  sample owner
    -> VisionImageInput
       -> scoped Span
          -> synchronous import or H2D completion
             -> releaseInput()
                -> inference on provider-owned memory
```

`releaseInput()` is idempotent. It prevents future borrows and removes
OpenVision's source reference. A provider must not call it while an
asynchronous accelerator still reads source memory.

The input contract has three separate immutable values:

| Value | Meaning | Does not mean |
|---|---|---|
| `VisionImageLayout` | Dimensions, pixel format, packed/planar planes, row stride, accessible byte extent | Storage ownership or GPU accessibility |
| `VisionImageStorageDescriptor` | Memory domain, ownership, lendable access, and transfer modes the source can satisfy | The transfer selected for this session |
| `VisionSessionConfiguration.transferMode` | The one transfer path selected by the composition root | Permission to fall back to another path |

Before session creation, OpenVision verifies that the provider advertises the
selected transfer. Before request dispatch, it verifies request, pixel format,
memory domain, ownership, selected transfer, and compute device against both
provider capabilities and the concrete input descriptor. A mismatch is a typed
failure and never selects another transfer or backend.

The sample-buffer initializer is a host-byte lending boundary. It accepts only
descriptors containing `hostBytes` because the erased `CMSampleBuffer` contract
currently exposes scoped pixel bytes but not a type-erased native resource
lease. Therefore, `directDeviceAccess` and `importedExternalMemory` cannot be
claimed through this initializer and fail explicitly. A future native-resource
initializer must retain a concrete OpenCoreVideo native lease and prove its
import synchronization before advertising those modes.

`retainedHostAccess` performs no OpenVision copy and leaves bytes in their
source storage. `stagedHostToDevice(fullFrameCopyCount: 1)` authorizes exactly
one provider-owned full-frame H2D transfer. The copy count describes the
complete frame, not small layout metadata or compact observations.

The core creates no `Data`, `[UInt8]`, or frame-sized storage. Compact
observation dictionaries are allowed because they outlive provider-owned tensor
storage and contain at most the request's bounded joint vocabulary.

The first TensorRT path may report one staged host-to-device transfer. Direct
device access or imported external memory may be advertised only after the
provider proves import support and synchronization on the actual storage type.

## Semantic model contract

`VisionModelManifest` describes meaning; a provider artifact describes one
compiled implementation of that meaning. OpenVision validates stage order,
tensor shapes, region dependencies, joint vocabulary, coordinate conversion,
quality bounds, and model provenance without importing a GPU runtime.

```text
VisionImageInput
    -> VisionModelManifest
        ├─ person detector input/output meaning
        ├─ bounded ROI and region-affine contract
        ├─ pose SimCC tensor meaning
        └─ body/hand joint mapping
            -> provider-selected compiled artifact
                -> compact OpenVision observations
```

The manifest contains no model weights, engine bytes, CUDA pointer, Metal
resource, or cache path. Those are provider-owned artifact concerns. RGB
normalization is represented as three scale and three bias values so a provider
can apply it directly in a fused tensor-writing kernel. No OpenVision operation
copies frame bytes while validating or carrying the manifest.

Tensor dimensions distinguish a fixed extent, a bounded batch extent, and a
bounded runtime-variable extent. Detector output count uses the variable form:
the RTMDet export produces `dets[1,N,5]` and `labels[1,N]`, where `N` is
bounded by the manifest rather than asserted to be a fixed output length.
Element types preserve the exported representation, including 64-bit class
indices.

The portable runtime fixture owns one initialized stack word, lends its original
address through `CVExternalPixelBufferStorage` and the fixed-layout
`CVPackedPixelBuffer`, constructs the real Core Media and OpenVision input path,
and verifies address identity before release. The release handler executes while
the stack owner remains alive and performs no deallocation. This exercises the
cross-module production buffer path without copying frame bytes.

## Clock, coordinate, and calibration provenance

OpenVision does not infer a clock identity from a numeric `CMTime`.
`VisionTimestamp` is the pair of a numeric time and a `VisionClockDomain`.
The domain includes an identifier, epoch, and source kind. Equal numeric values
from unequal domains are not comparable evidence.

```text
Capture frame
  ├─ CMSampleTimingInfo.presentationTimeStamp
  ├─ VisionClockDomain(id + epoch)
  ├─ VisionFrameID(source + sequence)
  └─ VisionCameraCalibration(revision + validity)
          │
          ▼
VisionImageInput
  ├─ source pixels: upper-left, x right, y down
  └─ normalized image: lower-left, x right, y up
          │
          ▼
VisionObservationProvenance
```

`VisionCameraCalibration` is an immutable snapshot. It contains the camera
source, revision, calibration timestamp, validity interval, pinhole intrinsics,
reference dimensions, optional pixel size, and optional radial-tangential lens
distortion. It intentionally does not claim a camera-to-room transform.
Room/appliance extrinsics belong to the layer that owns room geometry.

`VisionCoordinateTransform2D` binds a matrix to source and destination space
identifiers, transform revision, clocked validity interval, and optional exact
calibration revision. Applying a transform checks all of these values before
matrix arithmetic. A clock mismatch, source-space mismatch, calibration
mismatch, expired transform, or invalid homogeneous scale is a typed failure;
there is no identity fallback. The operation accepts and returns
`VisionLocatedPoint2D`, so the destination space, timestamp, calibration, and
applied transform revision remain attached to the result rather than becoming
out-of-band caller state.

Body and hand observation initializers require an explicit
`VisionObservationProvenance`. Tests may deliberately use
`unattributedNormalizedImage`, but a provider cannot omit provenance and obtain
that value through a default argument.

The following Apple declarations were checked in the Xcode 27 beta interface
and with `remark` on 2026-07-26:

| Apple declaration | OpenVision declaration | Difference and reason |
|---|---|---|
| `Vision.CoordinateOrigin` | `CoordinateOrigin` | Same upper-left/lower-left cases |
| `Vision.NormalizedPoint` image conversion | `NormalizedPoint` conversion using `CVPixelDimensions` and `VisionPoint2D` | CoreGraphics is unavailable on portable targets |
| `VisionObservation.timeRange` | `timeRange` plus `VisionObservationProvenance.timestamp` | The portable provenance adds an explicit clock domain and rejects inconsistent ranges |
| `HumanBodyPose3DObservation.cameraOriginMatrix` | Future 3D observation transform | 2D pose does not fabricate a 3D camera transform |
| `AVCameraCalibrationData.intrinsicMatrix` and reference dimensions | `VisionCameraIntrinsics` | Portable row-major value type; no Objective-C or simd dependency |
| `AVCameraCalibrationData` distortion lookup tables | `VisionLensDistortionModel.radialTangential` | Bounded coefficients avoid copying opaque frame-sized tables; additional models require explicit typed cases |
| `CMClock` / `CMSync` clock identity and conversion | `VisionClockDomain`, `VisionTimestamp`, `VisionTimeRange` | OpenCoreMedia owns clock execution; OpenVision carries immutable provenance |

## Concurrency

- Short counters and input-owner state use `Mutex`.
- Provider sessions use actors because execution ordering, cancellation, and
  device lifecycle can suspend.
- No `await`, I/O, provider callback, or event emission occurs under a mutex.
- The initial real-time policy allows one in-flight TensorRT inference. Busy
  submissions fail explicitly; a capture composition may then keep the newest
  frame.

The shared-state contract is identical on every target:

| Logical state | Native storage / isolation | WASM storage / isolation | Embedded storage / isolation | Read / mutation / release |
|---|---|---|---|---|
| Input sample owner | `Mutex<State>` | `Mutex<State>` | `Mutex<State>` | `isReleased` and `retainedImageBuffer()` / `releaseInput()` / idempotent reference release |
| Execution sequence | `Mutex<UInt64>` | `Mutex<UInt64>` | `Mutex<UInt64>` | `next(sessionID:)` performs checked increment / owner deinit |
| Provider device lifecycle | provider actor | provider actor | provider actor | request methods / cancellation and `shutdown()` |

There is no `hasFeature(Embedded)` or `canImport(Synchronization)` branch in
these paths. Locks contain only short memory access; pixel borrowing, provider
callbacks, `await`, and shutdown occur after the lock is released.

## Portable differences from Apple

Foundation and Objective-C runtime types are not available on all targets.
OpenVision therefore uses `VisionObservationID`, `VisionImageOrientation`, and
`VisionComputeDeviceID`. These are semantic equivalents, not type aliases to
`UUID`, `CGImagePropertyOrientation`, or `MLComputeDevice`.
