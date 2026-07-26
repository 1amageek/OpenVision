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

## Verification evidence

| Check | Current evidence |
|---|---|
| Native OpenVision behavior | 41 tests passed with `xcodebuild test` and Swift 6.4 snapshot |
| Native sanitizers | The same 41 tests passed with Address Sanitizer and Thread Sanitizer |
| External provider | Public `OpenVisionProviderFixture` commit `24982ec` passed 3 Native, Address Sanitizer, and Thread Sanitizer tests against OpenVision `6348722` without SPI or `@testable` |
| TensorRT package compatibility | Public `OpenVisionTensorRT` commit `eae92b3` passed 19 Native, Address Sanitizer, and Thread Sanitizer tests against OpenVision `6348722` |
| Normal WASM | Debug and release build plus `OpenVisionPortableSmoke` run passed with 2026-07-17 SDK |
| Embedded WASM | Debug and release build plus `OpenVisionPortableSmoke` run passed with 2026-07-17 Embedded SDK and Unicode data tables |
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
| 6. TensorRT engine and provider | Not started | Requires manifest and preprocessing |
| 7. Camera-to-pose observation | Not started | Requires real provider execution |

## Known dependency defect

The pinned Swift 6.4 regular-WASI runtime traps when a downstream executable
constructs OpenCoreVideo's cross-module generic
`CVExternalPixelBufferStorage` or `CVPackedPixelBuffer`. Embedded WASM does not
show the same trap. The OpenVision runtime fixture therefore uses the public
`CVPixelBuffer` protocol directly and proves the framework boundary without
claiming that the affected OpenCoreVideo convenience path passed. This defect
must be resolved in OpenCoreVideo before that generic path is release-ready on
regular WASM.

## Tracked next work

- [ ] Add a stateful request only with ordered timestamp, reset, cancellation,
  and bounded-history tests.
- [ ] Implement the matching RTMDet-nano and DWPose-m TensorRT engines,
  region-affine preprocessing, decoding, and provider execution.
- [ ] Complete checkpoint and training-dataset license review before product
  distribution.
- [ ] Evaluate ceiling-view accuracy and false positives before accepting the
  bring-up model as a product model.
- [ ] Measure 1920x1080 RG10 30 FPS behavior, allocation count, copy count,
  p50/p95 latency, resident/device memory, power, and thermal state on Jetson.

No production CPU, Apple Vision, or Metal provider is part of the current
implementation.
