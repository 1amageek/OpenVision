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
- [x] Native behavior tests
- [x] External-package provider conformance fixture
- [x] Normal WASM compile, link, and runtime smoke
- [x] Embedded WASM compile, link, and runtime smoke

## Verification evidence

| Check | Current evidence |
|---|---|
| Native OpenVision behavior | 14 tests passed with `xcodebuild test` and Swift 6.4 snapshot |
| External provider | 3 tests passed from a separate SwiftPM package without SPI or `@testable` |
| Normal WASM | Build and `OpenVisionPortableSmoke` run passed with 2026-07-17 SDK |
| Embedded WASM | Build and `OpenVisionPortableSmoke` run passed with 2026-07-17 Embedded SDK |
| Input storage | Address-preserving borrow and exactly-once release are tested |
| Provider dispatch | Stage-specific compute-device checks and active cancellation are tested |
| Silent fallback | Missing provider, unsupported request, format, memory domain, ownership, and combined cleanup failure are tested |

## Tracked next work

- [ ] Add complete coordinate-space, calibration, clock-domain, and transform
  provenance types before publishing 3D or cross-camera geometry.
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
