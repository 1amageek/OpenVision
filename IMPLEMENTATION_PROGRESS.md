# OpenVision Implementation Progress

## Implemented

- [x] Swift 6.4 package using URL dependencies
- [x] Portable normalized geometry and observation identities
- [x] Body and hand pose request and observation contracts
- [x] Typed provider capabilities, model descriptors, failures, cancellation
  identifiers, and lifecycle
- [x] Task-local explicit provider scope
- [x] Embedded-compatible composite provider session without dynamic casts
- [x] `VisionImageInput` scoped byte borrow and early release contract
- [x] Immutable packed and planar input layout snapshots
- [x] Storage access, memory-domain, ownership, and transfer descriptors
- [x] Explicit session transfer selection without fallback
- [x] Address-preserving generic `Span` borrow with typed body failure
- [x] Typed clock domains, timestamps, and validity ranges
- [x] Explicit image coordinate origins, units, axes, and conversions
- [x] Revisioned camera intrinsics and lens-distortion calibration
- [x] Revisioned clocked 2D transforms with compatibility failures
- [x] Observation provenance propagated from image input
- [x] Native behavior tests
- [x] External-package provider conformance fixture
- [x] Normal WASM compile, link, and runtime smoke
- [x] Embedded WASM compile, link, and runtime smoke
- [x] Validated backend-neutral semantic model manifest
- [x] Ordered model stages and typed detector-to-region dependencies
- [x] Fixed, bounded-batch, and bounded-variable tensor shape contracts
- [x] Exact tensor element types, including 64-bit detector class indices
- [x] Complete request-specific body and hand joint vocabulary validation
- [x] Exact checkpoint provenance and SHA-256 identity
- [x] Per-channel tensor normalization and region-affine semantics
- [x] Apple-shaped `StatefulRequest` lifecycle contract
- [x] Session- and epoch-scoped `VisionTrackID`
- [x] Backend-neutral stateful body-pose tracking over compact joints
- [x] Ordered frame/timestamp validation, frame analysis spacing, reset, and
  shutdown
- [x] Bounded gaps, reacquisition, multi-pose association, cancellation, and
  concurrent-call rejection

## Verification evidence

| Check | Current evidence |
|---|---|
| Native OpenVision behavior | 54 tests passed with `xcodebuild test` and the 2026-07-17 Swift 6.4 snapshot |
| Stateful tracking sanitizers | The 13 stateful tracking tests passed independently with Address Sanitizer and Thread Sanitizer |
| External provider | The public `OpenVisionProviderFixture` passed against this local OpenVision through public API only, without SPI or `@testable` |
| TensorRT package compatibility | A clean integration copy of the current `OpenVisionTensorRT` worktree passed 34 tests against this local OpenVision; the source worktree was not modified |
| Normal WASM | Debug and release build, link, and `OpenVisionPortableSmoke` execution passed with the 2026-07-17 SDK, including tracking actor reset/shutdown behavior |
| Embedded WASM | Debug and release build, link, and `OpenVisionPortableSmoke` execution passed with the 2026-07-17 Embedded SDK and WASM Unicode data tables, including tracking actor reset/shutdown behavior |
| Input storage | Packed/planar layout, address identity, typed borrow failure, transfer validation, release, and unavailable native access are tested |
| Provider dispatch | Stage-specific compute-device checks and active cancellation are tested |
| Silent fallback | Missing provider, unsupported request, format, memory domain, ownership, and combined cleanup failure are tested |

## Milestones

| Milestone | Status | Gate evidence |
|---|---|---|
| 1. Input layout, storage, and transfer | Complete | 22 Native tests, ASan, TSan, and Normal/Embedded WASM debug/release runtime |
| 2. Clock, coordinate, and calibration | Complete | 31 Native tests, ASan, TSan, public external-provider and TensorRT compatibility, and Normal/Embedded WASM debug/release runtime |
| 3. Jetson CUDA transfer probe | Complete | Public `OpenVisionTensorRT` commit `dc27ec9`; real CUDA transfer, ownership, byte verification, allocation, and p50/p95 evidence |
| 4. RG10 GPU preprocessing | Complete | Public `OpenVisionTensorRT` commit `eb7d761`; 25 differential/golden cases, public Swift path, one H2D, one kernel, zero post-prepare frame allocations, and p50/p95 evidence |
| 5. Semantic model manifest | Complete | 41 core tests, official ONNX output type/shape verification, sanitizers, Normal/Embedded WASM, published provider fixtures, and real Jetson CUDA differential execution |
| 6. TensorRT engine and provider | Complete | Current TensorRT package implements RTMDet/DWPose execution, provider conformance, compact observation construction, sustained fixture execution, and passes 34 local integration tests |
| 7. Camera-to-pose observation | In progress | Production GPU provider succeeds on 1920x1080 RG10 fixtures; a real WAVESHARE-26185 camera frame lease and sustained capture remain |
| 8. Stateful body-pose tracking | Complete | 13 behavior tests cover identity continuity, reset epoch, spacing, gaps, reacquisition, two poses, bounded capacity, metadata, zero-copy borrow identity, source/clock/frame ordering, concurrency, cancellation, and shutdown; Native sanitizers and WASM/Embedded smoke pass |

## Resolved dependency defect

OpenCoreVideo `adb0ff9` replaced the affected cross-module dependent class
layouts with fixed-layout `CVExternalPixelBufferStorage` and
`CVPackedPixelBuffer` owners. OpenVision now uses that production path in its
portable runtime fixture and verifies the original storage address through
OpenCoreMedia and `VisionImageInput`. Native tests and regular/Embedded WASM
debug and release runtimes passed against the remote OpenCoreVideo revision on
2026-07-27; the previous generic-layout runtime trap is no longer an open gate.

## Tracked next work

- [ ] Connect the WAVESHARE-26185 camera lease to the production TensorRT
  provider and measure sustained 1920x1080 RG10 at 30 FPS.
- [ ] Evaluate temporal track continuity, ID switches, occlusion recovery, and
  crossing paths on ceiling-view sequences before treating spatial tracking as
  product-quality identity evidence.
- [ ] Complete checkpoint and training-dataset license review before product
  distribution.
- [ ] Evaluate ceiling-view accuracy and false positives before accepting the
  bring-up model as a product model.
- [ ] Measure 1920x1080 RG10 30 FPS behavior, allocation count, copy count,
  p50/p95 latency, resident/device memory, power, and thermal state on Jetson.

No production CPU, Apple Vision, or Metal provider is part of the current
implementation.
