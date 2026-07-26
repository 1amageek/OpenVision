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

## Verification evidence

| Check | Current evidence |
|---|---|
| Native OpenVision behavior | 31 tests passed with `xcodebuild test` and Swift 6.4 snapshot |
| Native sanitizers | The same 31 tests passed with Address Sanitizer and Thread Sanitizer |
| External provider | 3 tests passed against public commit `673ce03` from a separate SwiftPM package without SPI or `@testable` |
| TensorRT package compatibility | 3 runtime-boundary tests passed against public commit `673ce03` |
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
| 3. Jetson CUDA transfer probe | Not started | Requires milestone 2 |
| 4. RG10 GPU preprocessing | Not started | Requires measured transfer probe |
| 5. Semantic model manifest | Not started | Requires pose-paper and model evidence |
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
- [ ] Select a semantic body/hand model before implementing successful
  TensorRT pose inference.
- [ ] Implement and measure RG10 CUDA preprocessing, one-copy H2D input,
  TensorRT execution, decoding, and input-consumed synchronization.
- [ ] Measure 1920x1080 RG10 30 FPS behavior, allocation count, copy count,
  p50/p95 latency, resident/device memory, power, and thermal state on Jetson.

No production CPU, Apple Vision, or Metal provider is part of the current
implementation.
