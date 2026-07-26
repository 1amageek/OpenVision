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

## Verification

```bash
perl -e 'alarm 90; exec @ARGV' -- \
  xcodebuild test \
    -scheme OpenVision-Package \
    -destination 'platform=macOS' \
    -maximum-test-execution-time-allowance 60 \
    SWIFT_EXEC="$HOME/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a.xctoolchain/usr/bin/swiftc"

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
