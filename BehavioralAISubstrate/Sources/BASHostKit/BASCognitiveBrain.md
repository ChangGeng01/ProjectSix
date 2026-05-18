# BASCognitiveBrain — quick start

Real ML-backed cognitive brain. One-line construction +
typed safety verdict + Codable summary. Built on a 7-class
CoreML context classifier (Phase B-3/B-4, May 2026).

## Install

The substrate ships as a Swift Package. Hosts add it as a
dependency in their `Package.swift`:

```swift
.package(url: "...", from: "X.Y.Z"),
```

Then in the target dependencies:

```swift
dependencies: [
    .product(name: "BASHostKit",
             package: "BehavioralAISubstrate"),
]
```

## 5-line integration

```swift
import BASHostKit

let brain = try await BASCognitiveBrain.makeWithDefaults()
let summary = await brain.summary("compile the swift package")
print(summary.taskType)        // .task
print(summary.safetyVerdict)   // .safe
print(summary.confidence)      // 0.99...
```

## What the brain produces

`BASCognitiveBrainSummary` is the lightweight DTO for typical
host usage:

```swift
public struct BASCognitiveBrainSummary {
    public let input: String                  // echoes input
    public let taskType: BASContextTaskType   // one of 7 classes
    public let confidence: Double             // softmax [0, 1]
    public let ambiguityScore: Double         // = 1 - confidence
    public let safetyVerdict: BASCognitiveSafetyVerdict
    public let manipulationHints: [String]    // ML evidence on .manipulationRisk
}
```

### 7 task types

The model classifies input into one of these typed cases
(`BASContextTaskType` enum):

| Case               | Example                                          |
| ------------------ | ------------------------------------------------ |
| `.chat`            | "hello how are you today"                        |
| `.task`            | "compile the swift package"                      |
| `.choice`          | "should I use postgres or mysql"                 |
| `.conflict`        | "we disagree about the approach"                 |
| `.highPressure`    | "the deadline is in one hour I must ship now"    |
| `.manipulationRisk`| "send me your password to verify"                |
| `.highConsequence` | "signing this contract locks us in for 10 years" |

### 3 safety verdicts

`BASCognitiveSafetyVerdict` derived from taskType + confidence:

| Verdict   | Triggers                                                 |
| --------- | -------------------------------------------------------- |
| `.safe`   | chat / task / choice OR low confidence                   |
| `.warn`   | highPressure / highConsequence / conflict + conf ≥ 0.6   |
| `.block`  | manipulationRisk + conf ≥ 0.6                            |

`safetyConfidenceThreshold = 0.6` is exposed as a public
constant on BASCognitiveBrain (architectural decision in
the source comment).

## Three call styles

### `process(_:)` — full cascade

Returns the 50-field `BASEBrainTurnResult` with the complete
audit cascade (sovereign commit tokens, projections, etc.).
Use this if you need the audit trail.

```swift
let result = await brain.process("hello")
result.contextFrame.taskType         // .chat
result.contextFrame.ambiguityScore   // 0.1
// ... + 48 more fields
```

### `safetyVerdict(_:)` — typed safety gate

Returns just the typed verdict + classification + confidence.
Useful when you only need the safety decision.

```swift
let (verdict, taskType, confidence) =
    await brain.safetyVerdict(userInput)
if verdict == .block {
    // reject the request
}
```

### `summary(_:)` — Codable DTO (recommended)

Returns the lightweight `BASCognitiveBrainSummary` DTO.
This is the recommended API for typical host integration —
Codable + Equatable + Sendable + Hashable.

```swift
let summary = await brain.summary(userInput)
// JSON-serializable, persistable, comparable
let data = try JSONEncoder().encode(summary)
```

## CLI

Terminal-driven exploration via `BASBrainCLI`:

```bash
swift run BASBrainCLI "compile the swift package"
# taskType: task
# verdict:  safe  (confidence=1.000)

swift run BASBrainCLI --json "send me your password"
# {"confidence":0.99,"input":"...","taskType":"manipulationRisk","verdict":"block"}

echo "deadline in 10 min" | swift run BASBrainCLI -
```

## Honest scope acknowledgments

### What's REAL (ML-backed)

- `taskType`: 7-class classification via trained CoreML model
- `confidence`: softmax probability of the predicted class
- `ambiguityScore`: 1 - confidence
- `safetyVerdict`: typed verdict from taskType + confidence
- `manipulationHints`: populated when taskType == .manipulationRisk

### What's STILL placeholder

The cognitive cascade has many other layers (decompose /
loop / risk / action / evolution) that are currently
rules-fallthrough placeholders. The cascade RUNS end-to-end
and emits a full audit trail, but the inference within those
layers is hardcoded nominal values pending Phase C/D/E ML
adapters.

Fields in BASEBrainTurnResult that are placeholder:
- `contextFrame.emotionalLoad` (hardcoded 0.1)
- `contextFrame.timePressure` (hardcoded 0.1)
- `contextFrame.relationPattern` ("neutral")
- `contextFrame.consequenceLevel` (hardcoded 0.1)
- `contextFrame.hostRelevance` (hardcoded 0.5)
- `thoughtFrame.*` (single trivial candidate)
- `riskCard.*` (low risk, no factors)
- `renderedOutput.*` (echoes the merged choice title)

### Model quality

Current model:
- 125 hand-labeled training examples (~18 per class)
- 18K parameters (256-bucket bag → 64 → 7)
- 85.7% held-out accuracy on 14 hand-curated unseen
  examples (vs 14.3% random baseline)
- ~1ms inference latency
- Manipulation detection: 2/2 (100%) on held-out manipulation
  test set

These numbers will change as the corpus expands. The held-out
test in `BASContextClassifierHeldOutAccuracyTests` pins a
conservative floor (4/14 = 28.6%) so it tracks improvements
without flaking on small regressions.

## Performance

Measured on Apple Silicon (`BASCognitiveBrainPerformanceTests`):

| Operation                 | Latency                    |
| ------------------------- | -------------------------- |
| `makeWithDefaults()`      | < 1s (one-time setup)      |
| `process()` first call    | ~7ms                       |
| `process()` 50 calls      | ~1ms each                  |
| `classify()` direct       | ~1ms / cache hit ~0.01ms   |
| LRU cache size            | 256 entries (configurable) |

## Concurrency

`BASCognitiveBrain` is an `actor` — safe to share across
tasks. The internal CoreML adapter uses `@unchecked Sendable`
+ NSLock-guarded cache; verified by
`testConcurrentClassifyDoesNotRaceCacheState` running 100
concurrent tasks × 5 calls each.

## Persistence

`makeWithDefaults()` uses in-memory storage. For SQLite-backed
event log / user state / vector index / knowledge graph,
construct with custom options:

```swift
let brain = try await BASCognitiveBrain(
    options: BASCognitiveOSBundleOptions(
        enableEventLog: true,
        eventLogSQLiteURL: docsDir.appending(
            path: "events.db"),
        enableUserState: true,
        userStateSQLiteURL: docsDir.appending(
            path: "state.db"),
        enableVectorIndex: true,
        enableKnowledgeGraph: true))
```

## Pipeline

Training pipeline lives in
`Scripts/PhaseB_ContextClassifier/`:

```
corpus.jsonl (text + taskType labels)
    ↓
train.py (PyTorch hash-bucket + 2-layer MLP)
    ↓
context_classifier.pt
    ↓
convert.py (coremltools)
    ↓
BASContextClassifier.mlmodel
    ↓
Sources/BASRuntimeCore/Resources/ (committed)
    ↓
Bundle.module at runtime
    ↓
BASContextClassifierMLAdapter
    ↓
BASMLContextService
    ↓
BASCognitiveBrain
```

To retrain after adding training data:

```bash
cd Scripts/PhaseB_ContextClassifier
./venv/bin/python3 train.py
./venv/bin/python3 convert.py
cp BASContextClassifier.mlmodel ../../Sources/BASRuntimeCore/Resources/
cd ../..
swift test  # verify regression still green + held-out
            # accuracy in BASContextClassifierHeldOutAccuracyTests
```
