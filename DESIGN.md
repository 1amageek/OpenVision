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

Before dispatch, OpenVision validates the input pixel format, memory domain,
and ownership mode against provider capabilities. The current image input is
host-domain retained storage. A provider that requires device-domain input or
borrowed/external ownership fails with a typed error instead of silently
copying or selecting another backend.

The core creates no `Data`, `[UInt8]`, or frame-sized storage. Compact
observation dictionaries are allowed because they outlive provider-owned tensor
storage and contain at most the request's bounded joint vocabulary.

The first TensorRT path may report one staged host-to-device transfer. Direct
device access or imported external memory may be advertised only after the
provider proves import support and synchronization on the actual storage type.

## Concurrency

- Short counters and input-owner state use `Mutex`.
- Provider sessions use actors because execution ordering, cancellation, and
  device lifecycle can suspend.
- No `await`, I/O, provider callback, or event emission occurs under a mutex.
- The initial real-time policy allows one in-flight TensorRT inference. Busy
  submissions fail explicitly; a capture composition may then keep the newest
  frame.

## Portable differences from Apple

Foundation and Objective-C runtime types are not available on all targets.
OpenVision therefore uses `VisionObservationID`, `VisionImageOrientation`, and
`VisionComputeDeviceID`. These are semantic equivalents, not type aliases to
`UUID`, `CGImagePropertyOrientation`, or `MLComputeDevice`.
