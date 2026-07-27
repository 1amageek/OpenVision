# OpenVision

OpenVision is a portable Swift implementation of the request, observation, and
provider boundaries of Apple's Vision framework. The first implemented slice is
2D human body and hand pose.

OpenVision does not capture cameras, classify gestures, select appliances, or
perform IR or Matter operations.

```text
OpenCoreMedia sample
    -> immutable layout + storage descriptor
        -> selected transfer contract
            -> VisionImageInput scoped lease
                -> clock + coordinate + calibration provenance
                    -> Vision request
                        -> injected provider session
                            -> typed observation values
```

## Provider injection

Provider selection is explicit and task-scoped. Swift 6.4 currently requires
the typed closure signature to be stated when the closure body contains a
throwing request.

```swift
let observations = try await VisionContext.withProvider(
    provider,
    configuration: configuration,
    operation: {
        () async throws(VisionError) -> [HumanBodyPoseObservation] in
        try await DetectHumanBodyPoseRequest().perform(
            on: sampleBuffer
        )
    }
)
```

There is no mutable global provider registry and no CPU or alternate-provider
fallback.

Pose observations preserve the source frame, clocked timestamp, normalized
coordinate-space convention, calibration revision, and transform revision when
available. Different clock domains or stale calibration/transform revisions
fail explicitly instead of being treated as equivalent coordinates.
Pose observation construction requires explicit provenance, and coordinate
transforms return a located point carrying the destination space and applied
revision.

## Stateful pose tracking

`TrackHumanBodyPoseRequest` preserves a bounded visual track across ordered
frames. Inputs require a `VisionFrameID` and `VisionClockDomain`. The request
performs the configured GPU-backed body-pose inference through the injected
provider, then retains only compact joint metadata for association.

```text
camera frame -> provider Pose inference -> visual track ID
                                      X-> gesture or person identity
```

The track ID is scoped to one tracking session and reset epoch. It is not a
person identifier, and OpenVision does not interpret the sequence as a gesture.
Call `reset()` to start a new epoch and `shutdown()` when the request is no
longer used.

## Verification

```bash
perl -e 'alarm 90; exec @ARGV' -- \
  env TOOLCHAINS=org.swift.64202607171a \
  xcodebuild test \
    -scheme OpenVision-Package \
    -destination 'platform=macOS,arch=arm64' \
    -maximum-test-execution-time-allowance 60 \
    "LD_RUNPATH_SEARCH_PATHS=\$(inherited) $HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a.xctoolchain/usr/lib/swift/macosx/testing"

TOOLCHAINS=org.swift.64202607171a xcrun swift build \
  --swift-sdk swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a_wasm \
  --product OpenVisionPortableSmoke

TOOLCHAINS=org.swift.64202607171a xcrun swift build \
  --swift-sdk swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a_wasm-embedded \
  --product OpenVisionPortableSmoke \
  -Xlinker /path/to/libswiftUnicodeDataTables.a
```

The portable executable verifies the real Core Media to OpenVision input path,
packed layout metadata, the original borrowed address, the advertised one-copy
H2D mode, and idempotent input release. Run the emitted WASM module with a WASI
Preview 1 runtime in both debug and release configurations.

See [SPEC.md](SPEC.md), [DESIGN.md](DESIGN.md), and
[IMPLEMENTATION_PROGRESS.md](IMPLEMENTATION_PROGRESS.md).
