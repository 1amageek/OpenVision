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

The portable runtime fixture owns one initialized stack word, lends its original
address through a private `CVPixelBuffer` protocol conformance, constructs the
real Core Media and OpenVision input path, and verifies address identity before
release. The fixture is intentionally not `CVPackedPixelBuffer`: the pinned
Swift 6.4 regular-WASI runtime traps while constructing that cross-module
generic class. This dependency defect is tracked separately and is not hidden
by claiming that the generic convenience path passed.

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
