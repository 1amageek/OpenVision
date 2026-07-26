# OpenVision implementation guidance

- Read `SPEC.md`, `DESIGN.md`, and `APPLE_API_TRACE.md` before changing public
  API.
- Re-read the active Xcode Vision Swift interface before adding an Apple-named
  declaration.
- OpenVision may import OpenCoreMedia and OpenCoreVideo. It must not import a
  concrete inference provider, camera driver, Foundation, Core ML, Metal, CUDA,
  or TensorRT.
- Request execution uses explicit task-scoped provider injection. Do not add a
  mutable global registry or an implicit backend fallback.
- Keep `VisionImageInput` as an owner with scoped byte access. Do not publish or
  retain a pointer outside the borrow closure.
- Shared mutable state uses the same `Mutex<State>` or actor contract on Native,
  WASM, and Embedded. Do not use target-specific raw state.
- A declared unavailable operation returns a typed failure and carries the
  required incomplete marker when its production implementation is pending.
- Tests use Swift Testing and must be run with `xcodebuild test` plus a timeout.
