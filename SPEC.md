# OpenVision Specification

## 1. Status and normative language

This document is the handoff specification for the initial implementation of
`OpenVision`.

The terms **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are normative. A future
implementation must update this document when it intentionally changes a
boundary or public contract.

`OpenVision` means an open, portable implementation of the responsibilities
exposed by Apple's Vision framework. The `Open` prefix exists because this
package follows an Apple framework surface. It does not imply that every
downstream domain package must use the same prefix.

## 2. Purpose

`OpenVision` converts image-domain input into typed visual observations. It
provides Apple Vision-like requests, observations, coordinate conventions,
request execution, capability discovery, and explicit provider injection
without requiring Apple platforms.

```text
OpenCoreMedia / OpenCoreVideo input
              |
              v
      OpenVision request
              |
              | injected VisionProvider
              v
 External provider package
              |
              v
 Typed visual observations
```

The package is a visual perception framework. It is not a camera framework,
gesture language, interaction state machine, or home-automation runtime.

## 3. Apple framework evidence

The initial boundary was derived from the Vision framework shipped in:

- Xcode 27.0 beta, build `27A5209h`
- macOS 27.0 SDK
- `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk/System/Library/Frameworks/Vision.framework/Versions/A/Modules/Vision.swiftmodule/arm64e-apple-macos.swiftinterface`
- `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk/System/Library/Frameworks/Vision.framework/Versions/A/Headers/`

The implementation agent must re-read the exact framework interface used by
the selected toolchain before stabilizing public API. Apple documentation under
`developer.apple.com/documentation` must be read with `remark`.

Primary documentation:

- [Vision](https://developer.apple.com/documentation/vision)
- [VisionRequest](https://developer.apple.com/documentation/vision/visionrequest)
- [ImageProcessingRequest](https://developer.apple.com/documentation/vision/imageprocessingrequest)
- [VisionObservation](https://developer.apple.com/documentation/vision/visionobservation)
- [StatefulRequest](https://developer.apple.com/documentation/vision/statefulrequest)
- [DetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest)
- [DetectHumanHandPoseRequest](https://developer.apple.com/documentation/vision/detecthumanhandposerequest)
- [Detecting human actions in a live video feed](https://developer.apple.com/documentation/createml/detecting-human-actions-in-a-live-video-feed)

The inspected API establishes these Vision responsibilities:

| Framework area | Apple Vision responsibility | OpenVision responsibility |
|---|---|---|
| Request execution | Execute image-analysis requests over image/buffer inputs | Provide portable request execution |
| Observations | Return confidence, identity, geometry, and temporal metadata | Define typed, immutable observation values |
| Human pose | Produce body, hand, and 3D joint observations | Produce geometric pose observations |
| Stateful analysis | Preserve request state across ordered frames | Support stateful request instances |
| Tracking and motion | Track objects, optical flow, trajectories | Provide equivalent portable request families |
| Model integration | Run compatible Core ML-backed image requests | Expose a backend-neutral model request boundary |
| Compute capabilities | Select or report supported compute stages/devices | Expose typed backend capabilities |

Apple Vision includes temporal computer-vision operations such as tracking,
optical flow, trajectories, and 3D pose. Therefore, temporal processing is not
categorically outside this package. Semantic human action or gesture
classification is outside this package because no inspected Vision request
defines that product-level meaning. Apple's action-classification guidance
extracts pose with Vision, aggregates poses over time, and sends them to a
separate classifier.

## 4. Boundary

### 4.1 Owned responsibilities

`OpenVision` owns:

- request and observation contracts;
- image orientation, region-of-interest, normalized coordinate, and timestamp
  semantics;
- body pose, hand pose, and optional 3D pose estimation;
- object detection, recognition, tracking, motion, optical-flow, trajectory,
  segmentation, saliency, text, barcode, and registration request families as
  they are implemented;
- state retained by an individual stateful visual request;
- creation and lifecycle of visual track identifiers within a declared tracking
  session;
- backend capability discovery and explicit backend selection;
- conversion of backend results into stable OpenVision observations;
- explicit revision and feature support reporting;
- cancellation, shutdown, and typed request failures.

### 4.2 Excluded responsibilities

`OpenVision` must not:

- enumerate, configure, or capture from cameras;
- own an `AVCaptureSession` equivalent;
- classify a joint sequence as a semantic pose, gesture, or human action;
- interpret a visual track as a persistent person or actor identity;
- decide which appliance a person is pointing at;
- map a gesture to a command;
- call IR, Matter, network, or actuator tools;
- infer or persist product state;
- retain image history beyond the bounded lifetime required by a declared
  stateful request;
- silently substitute a different request, model, revision, or backend.

### 4.3 Dependency direction

In the following graph, `A -> B` means that package `A` imports package `B`.
It does not represent the direction in which frames flow at runtime.

```text
OpenVision -----------------------> OpenCoreMedia
     |                                      |
     +-------------------------------------> OpenCoreVideo

OpenVisionTensorRT ---------------> OpenVision
OpenVisionMetal (future) ---------> OpenVision
ActionRecognition ---------------> OpenVision

Lume ----------------------------> OpenVision
Lume ----------------------------> selected provider package
```

`OpenVision` may depend on `OpenCoreMedia` and `OpenCoreVideo`. It must not
depend on `OpenVisionTensorRT`, `OpenVisionMetal`, a Jetson-specific package,
ActionRecognition, Interaction, or Lume.

`OpenVisionTensorRT` is the first required concrete provider package. It imports
`OpenVision` and implements the public provider contracts for NVIDIA CUDA and
TensorRT environments, including Jetson. A future `OpenVisionMetal` package may
implement the same contracts for Apple GPU environments. The application or
product composition root imports `OpenVision` and exactly the provider packages
it intends to use, then injects the selected provider explicitly.

Jetson is a deployment environment rather than an OpenVision framework layer.
Jetson camera capture remains owned by
`OpenAVFoundationJetsonCameraDriver`, and Jetson GPU inference remains owned by
`OpenVisionTensorRT`. OpenVision accepts portable Core Media/Core Video input
and does not import either concrete implementation.

## 5. API compatibility policy

The modern Swift Vision API is the primary compatibility baseline. The first
implementation should establish these conceptual families:

- `VisionRequest`
- `ImageProcessingRequest`
- `StatefulRequest`
- `VisionObservation`
- request-specific observation types
- image request handling
- sequence request handling
- request descriptors, revisions, compute stages, and capabilities

Legacy `VN*` compatibility may be added after the portable execution core is
stable. Compatibility means equivalent call shape and semantics where the
portable environment can represent them. It does not mean importing
Objective-C runtime behavior into WASM or Embedded targets.

Every known divergence from Apple API must be recorded in a compatibility
matrix with:

1. Apple declaration;
2. OpenVision declaration;
3. semantic difference;
4. affected targets;
5. reason;
6. planned resolution or permanent limitation.

Unavailable functionality must fail through a typed unsupported-capability
error. It must not return empty observations as a successful result.

Apple Vision exposes Core ML compute-device values that are unavailable on the
portable targets. OpenVision must preserve the compute-stage and explicit-device
selection semantics through backend-neutral typed identifiers and capability
values. It must record this type difference in the compatibility matrix rather
than importing Core ML into the portable target.

## 6. Core data contracts

### 6.1 Input

The primary streaming input should accept an `OpenCoreMedia` sample buffer whose
image storage is backed by an `OpenCoreVideo` pixel buffer. Additional image
sources may be supported through explicit adapters.

Every input must carry, when available:

- a monotonic presentation timestamp;
- a typed clock-domain identifier;
- pixel format;
- dimensions and plane layout;
- orientation;
- color-space metadata;
- ownership or lease information;
- optional camera calibration and intrinsics.

Layout, storage capability, and selected transfer are distinct contracts.
`VisionImageLayout` describes packed or planar byte geometry. A storage
descriptor states the memory domain, ownership mode, lendable access, and every
transfer the concrete input can satisfy. Session configuration selects exactly
one transfer mode. Provider capability and input capability must both contain
that selected mode before execution.

The sample-buffer input initializer is allowed to advertise only host-byte
access because `CMSampleBuffer` exposes a scoped host borrow. Native-resource
access requires a separate retained native lease; merely labeling host bytes as
device or external memory is not sufficient. An unavailable native path must be
rejected as a typed failure.

### 6.2 Output

All observations must be immutable value types or immutable views over an
explicit owner. Common observation metadata should include:

- stable observation identifier;
- confidence;
- request descriptor and revision;
- source timestamp or time range;
- normalized geometry convention;
- typed coordinate and transform provenance;
- source frame identity when correlation is required.

Pose observations represent geometry and evidence. Joint names, chirality,
confidence, availability, 2D/3D coordinate space, and transform metadata must
be typed. A missing or occluded joint must remain missing or low-confidence;
it must not be synthesized as a high-confidence zero coordinate.

### 6.3 Coordinate contract

The package must define typed coordinate and transform provenance. A geometry
value that can cross a package boundary must carry or reference:

- coordinate-space identifier;
- source frame or camera identifier;
- transform revision;
- calibration revision;
- calibration timestamp in a typed clock domain;
- observation timestamp in a typed clock domain;
- transform validity interval;
- axis orientation, handedness, units, and normalization convention;
- uncertainty when it is produced by estimation.

OpenVision provides explicit transforms for source pixel coordinates,
normalized image coordinates, display coordinates, and camera-relative 3D
coordinates. Mirroring and rotation are metadata-driven. Callers must not need
device-specific coordinate guesses.

Transforms are immutable revisioned values. A transform cannot be applied when
its source space, destination space, clock domain, calibration revision, or
validity interval is incompatible with the geometry being transformed. Such a
case is a typed failure, not an identity-transform fallback.

Room or appliance geometry and camera-to-room calibration are not owned by
OpenVision. OpenVision preserves sufficient camera-space provenance for an
upper layer to perform that transformation.

### 6.4 Visual tracking identity

`VisionTrackID` identifies one visual tracking hypothesis within a declared
source, tracking session, and session epoch. It is not a person identifier.

A track observation must preserve:

- `VisionTrackID`;
- source identifier;
- tracking-session identifier and epoch;
- first and latest observation timestamps;
- confidence and tracking state;
- parent or predecessor track evidence when the backend exposes it.

Reusing the same scalar identifier in another session or epoch does not imply
identity. OpenVision must not reconnect a lost track by claiming that it is the
same human actor. Mapping one or more visual tracks to an `ActorID` belongs to
ActionRecognition.

## 7. Public provider contract

Backend implementations are replaceable. The portable public API depends on
small provider protocols rather than TensorRT, Core ML, ONNX Runtime, Metal, or
platform camera APIs.

The provider extension point is public API from the first implementation phase.
An independently versioned package must be able to import `OpenVision`, conform
to the provider protocols, and execute OpenVision requests without using
`internal`, `package`, underscored, or SPI declarations.

The public provider contract has two lifecycle roles:

| Role | Responsibility |
|---|---|
| `VisionProvider` | Report capabilities and create configured execution sessions |
| `VisionProviderSession` | Execute typed requests, preserve declared state, cancel work, and shut down |

These names are normative role names. The implementation agent may adjust a
name only before API stabilization and must record the equivalent public
declaration in the compatibility matrix.

The public contracts must expose:

- supported request kinds and revisions;
- accepted pixel formats and memory domains;
- supported compute devices;
- batch and streaming constraints;
- a typed input-ownership mode distinguishing borrowed, retained, imported, and
  copied storage;
- ordering and concurrency guarantees;
- creation of a stateful execution session;
- typed request execution returning the request's declared result type;
- cancellation correlated to submitted work;
- model preparation and execution lifecycle;
- shutdown behavior;
- typed provider failures;
- provider and model provenance and revision.

The OpenVision package owns the portable request, result, capability,
configuration, ownership, session, cancellation, and error types. External
provider packages own runtime-specific engine and device types. CUDA, TensorRT,
Core ML, Metal, and ONNX Runtime types must not appear in the OpenVision public
contract.

Provider selection is explicit dependency injection. Runtime-wide mutable
registries and implicit global provider discovery are not required and must not
be the only integration path. OpenVision must not inspect the host platform and
silently select TensorRT, Metal, a CPU path, or any other provider.

The Apple-shaped `request.perform(on:)` surface resolves its session from a
lexically scoped `VisionContext.withProvider` operation. The scope uses
`TaskLocal` storage, creates exactly one provider session, restores an outer
scope after nesting, and shuts the session down on success or failure. It is not
a process-global registry. Calling `perform(on:)` outside a configured scope is
a typed `providerNotConfigured` failure.

`VisionProviderSession` refines the request-family provider protocols instead
of discovering them with runtime casts. A provider advertises only the requests
it supports. The default implementation of an unimplemented request-family
method returns a typed unsupported-request failure. This composite protocol
shape is required because Embedded Swift does not provide dynamic casting.

Provider packages in the current architecture are:

| Provider package | Status | Intended role |
|---|---|---|
| `OpenVisionTensorRT` | Required first implementation | NVIDIA CUDA and TensorRT inference, including Jetson |
| `OpenVisionMetal` | Future | Apple GPU inference for Mac development and Apple deployments |
| WASM provider | Future or explicitly unavailable | Browser or WASI-compatible GPU inference |
| Embedded provider | Future or explicitly unavailable | Board-specific bounded GPU or accelerator inference |

The initial program does not require an Apple Vision adapter or a production CPU
inference provider. Deterministic test doubles and small mathematical reference
functions may be used to validate contracts, preprocessing, coordinate
conversion, and tensor decoding. They are test support, not successful
production inference providers.

An external provider conformance is accepted only when a separate fixture
package compiles using public API alone and tests capability reporting,
successful execution, unsupported requests, cancellation, buffer lifetime, and
shutdown. Internal adapters may exist, but they cannot be the extension
contract used by `OpenVisionTensorRT`, `OpenVisionMetal`, or another provider
package.

### 7.1 Model and artifact boundary

OpenVision owns backend-neutral model identity and schema values:

- semantic model identifier and revision;
- request family and observation schema;
- input dimensions, pixel interpretation, orientation policy, and color range;
- resize, crop, letterbox, and normalization contract;
- output tensor meaning, joint vocabulary, and coordinate convention;
- precision and quality requirements;
- provenance and compatibility metadata.

Provider packages own compiled runtime artifacts. A TensorRT engine and a
Metal-compatible model artifact may implement the same semantic model revision,
but they are distinct artifacts with independent compatibility, checksum,
preparation, cache, and lifecycle metadata. Runtime artifact or engine types
must not appear in OpenVision public API.

## 8. Zero-copy and ownership

The streaming image path is performance-critical and must be designed as:

```text
Capture owner
    -> buffer lease
        -> plane/span borrow
            -> provider import, staging transfer, or direct device access
                -> accelerator input-consumed completion
                    -> release input lease
                        -> compact observations
```

Required rules:

- Do not materialize a frame as `Data`, `[UInt8]`, or a new pixel array at every
  stage.
- Keep the storage owner alive until the provider proves that every asynchronous
  accelerator read from that storage has completed. A provider may release the
  input after an input-consumed fence while inference continues on
  provider-owned device memory.
- `VisionImageInput` owns the framework's sample-buffer reference and exposes
  only scoped byte borrows. A provider calls `releaseInput()` only after every
  source-memory read has completed. The request wrapper also releases the input
  on every success, failure, and cancellation exit.
- Expose scoped borrows, planes, ranges, or leases; do not let raw pointers
  escape their valid lifetime.
- Record every unavoidable full-frame copy and the boundary that requires it.
- Report a typed transfer or import mode that distinguishes direct device
  access, imported external memory, retained host access, and staged
  host-to-device copy. Integrated physical memory alone is not proof of
  zero-copy accelerator access.
- A staged transfer must declare a positive full-frame copy count. The initial
  TensorRT path permits exactly one H2D copy. OpenVision itself performs zero
  frame-byte copies.
- The provider may borrow a source address only inside the synchronous borrow
  closure. Asynchronous CUDA work must complete its source read, or copy into
  provider-owned memory, before the closure returns and before
  `releaseInput()`.
- Pixel-format conversion must use a reusable buffer pool when in-place or
  backend import is impossible.
- Image-sized preprocessing belongs to the concrete GPU provider. For the first
  Jetson camera path, RG10 demosaic, orientation, mirroring, resize, letterbox,
  and normalization are implemented by `OpenVisionTensorRT` GPU targets rather
  than OpenVision core.
- Observation output must not retain the full frame unless a request explicitly
  documents that behavior.
- Benchmarks must report frame size, frame rate, copy count, allocations,
  latency distribution, throughput, and peak resident memory.

Unsafe code must be isolated behind a safe owner/lease API and document memory
owner, deallocation, alignment, initialized range, binding, aliasing, and
synchronization invariants.

## 9. Failure, concurrency, and lifecycle

The package must define typed failures covering at least:

- invalid input buffer or metadata;
- unsupported request or revision;
- unsupported pixel format or memory domain;
- backend unavailable;
- model unavailable or incompatible;
- allocation or resource exhaustion;
- invalid timestamp ordering for a stateful request;
- incompatible coordinate space, clock domain, calibration, or transform
  revision;
- expired transform or calibration;
- cancelled request;
- request already shut down;
- backend execution failure.

The exact public error types are an implementation decision, but failure must
never be rounded into a successful empty observation.

Stateful request instances own their temporal state and must define whether
concurrent calls are rejected or serialized. Short memory-only shared state
uses `Mutex<State>` on Native, WASM, and Embedded with the same storage and
access contract. Ordered asynchronous execution or I/O uses an actor. No
`await`, external callback, or event emission may occur while a mutex is held.

Any public asynchronous stream must have an explicit `shutdown()` path that
finishes its continuation. Cancellation must release all retained leases.

## 10. Platform contract

The shared public model must compile under the fixed Swift 6.4 development
snapshot and matching SDK for:

- native Apple platforms;
- normal WASM;
- Embedded WASM.

Platform differences belong in backend implementations and capability values,
not in weakened public ownership, synchronization, or failure contracts.
Objective-C interoperability, reflection, Core ML, Accelerate, Metal, and
Foundation must not be assumed by the shared portable target.

Provider support is independent of OpenVision core portability:

| Package | Initial platform contract |
|---|---|
| `OpenVision` | Native, WASM, and Embedded WASM compile/link |
| `OpenVisionTensorRT` | NVIDIA CUDA/TensorRT environments, with Jetson as the first runtime target |
| `OpenVisionMetal` | Future Apple GPU provider |

Compiling OpenVision on a target does not imply that a concrete inference
provider exists there. An application that does not inject a compatible
provider receives a typed unavailable or unsupported result.

## 11. Implementation sequence

### Phase 0: API evidence

- Capture the relevant local Vision module declarations and headers.
- Produce the Apple/OpenVision compatibility matrix.
- Finalize the public `VisionProvider` and `VisionProviderSession` contracts,
  including ownership, cancellation, and shutdown.
- Finalize `VisionTrackID`, coordinate provenance, clock-domain, calibration,
  and transform-revision value contracts.
- Compile an external provider fixture using public API only.
- Select the first request slice; do not declare unsupported request families
  as successful stubs.

### Phase 1: Portable core

- Implement request descriptors, observations, coordinates, time, revisions,
  capabilities, typed failures, and lifecycle.
- Implement public provider and provider-session contracts.
- Integrate zero-copy `OpenCoreMedia` and `OpenCoreVideo` input leases.
- Compile and link Native, WASM, and Embedded WASM.

### Phase 2: Pose slice

- Implement body and hand pose request contracts.
- Add deterministic provider test doubles and mathematical reference fixtures.
  These fixtures must not be advertised as a CPU inference backend.
- Verify orientation, mirroring, missing joints, confidence, ordering, failure,
  cancellation, and shutdown behavior.

### Phase 3: TensorRT provider integration

- Keep all CUDA, TensorRT, NVIDIA, Linux, and Jetson implementation in the
  separate `OpenVisionTensorRT` package.
- Prove that `OpenVisionTensorRT` can implement the provider contract using
  public OpenVision API only.
- Integrate the real Jetson camera `CMSampleBuffer` path without importing the
  camera driver into OpenVision.
- Verify GPU preprocessing, model execution, observation conversion,
  cancellation, input-consumed lease release, and shutdown.
- Measure copies, allocations, GPU synchronization, throughput, p50/p95
  latency, memory, power, and thermal behavior.

### Phase 4: Stateful vision

- Implement the stateful request execution contract.
- Add tracking or another genuinely temporal visual request.
- Verify gaps, out-of-order timestamps, reset, concurrent calls, and bounded
  state.

### Phase 5: compatibility expansion

- Add request families only with real implementation paths and behavioral
  tests.
- Add legacy `VN*` surface only where its semantics can be upheld.

## 12. Verification and completion criteria

An implementation phase is complete only when:

- declarations execute a real backend or return a typed unsupported failure;
- success and failure behavior are tested;
- native tests use `xcodebuild test` with a timeout;
- Native, WASM, and Embedded WASM compile and link with the fixed matching
  toolchain and SDK;
- executable targets have runtime lifecycle tests;
- zero-copy claims have copy/allocation evidence;
- Apple API compatibility is checked against the exact local Swift interface
  and headers; an Apple Vision runtime adapter is not required for the initial
  implementation;
- an out-of-package provider compiles and runs without SPI access;
- provider selection is explicit and an unavailable provider is not replaced by
  a CPU or alternate GPU fallback;
- model semantic revision and provider artifact revision remain separately
  identifiable;
- `VisionTrackID` is never exposed as an actor or persistent person identity;
- stale or incompatible coordinate transforms fail explicitly;
- all `FIXME(INCOMPLETE_IMPLEMENTATION)` markers are reflected in the progress
  document;
- no product vocabulary or interaction policy has leaked into this package.

## 13. Handoff checklist

Before implementing:

1. Read the workspace and CoreFoundation `AGENTS.md`.
2. Inspect the exact local Vision framework API, not only online summaries.
3. Read Apple documentation with `remark`.
4. Inspect `OpenCoreMedia` and `OpenCoreVideo` ownership contracts.
5. Write the compatibility matrix and initial request scope.
6. Finalize the public provider-session, compute-device, input-transfer,
   cancellation, and shutdown contracts required by an external
   `OpenVisionTensorRT` package.
7. Define the backend-neutral model manifest and preprocessing schema.
8. Define copy, allocation, latency, memory, power, and thermal budgets.
9. Record every unavailable declaration with the required incomplete marker and
   typed failure.
