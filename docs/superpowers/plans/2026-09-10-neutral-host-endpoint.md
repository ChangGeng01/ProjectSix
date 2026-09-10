# Neutral host endpoint implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for
> Task27, only after Task26 source handback and independent acceptance.

**Goal:** give the selected host-integration leaf a public provider-neutral
way to reuse the existing endpoint without copying its dispatcher.

**Architecture:** add one small factory over the existing private registry
and package endpoint. The trusted host supplies the already-composed adapter
and exact selected identity. No concrete provider, model loader or recovery
dependency is introduced into the SDK.

**Tech Stack:** existing Swift/BASOrgan/QinaoLoop and XCTest.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md` choice10;
the accepted neutral-bridge section of the solo workspace's
`qinao-provider-inversion-design.md`. Full inversion and App storage-first
composition remain required later; this API does not complete those changes.

## Global constraints

- Preserve old code/tests/history/drafts. No model invocation, load/provision,
  cloud/PCC, fallback, provider selection, real App run, scan or Git writes by
  the implementer. Existing registry/endpoint behavior stays unchanged.
- No new SDK dependency/product, BASHostKit import, public registry, override
  closure, endpoint implementation type or request-ID hook. Use the already
  accepted public provider-neutral BASOrganAdapter parameter.
- No memoization, shared-generation owner, transcript store or recovery claim
  in this seam. Eager and stream calls still represent separate requests.
- Existing concrete-runtime boundary and shared-operation failures remain
  unresolved. Do not weaken, skip or rewrite those tests to claim this fixes them.

## Task27: Public neutral factory with actual invocation tests

**Files:**

- Create `QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpointFactory.swift`.
- Modify `QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/BASOrganRegistryEndpointIdentityTests.swift`.

**Public implementation:**

```swift
import BASOrgan

public enum QinaoEndpointPreset: Sendable {
    case roleDefaults
    case greedyDeterministic
}

extension QinaoLoop {
    /// Compose only the host-supplied adapter. This does not load or select a
    /// model. A missing selected identity refuses at invocation; it never
    /// falls back to the registered adapter. Streaming/routing refinements
    /// are preserved by the existing endpoint implementation.
    public static func makeOrganEndpoint(
        selectedProviderID: String,
        adapter: any BASOrganAdapter,
        preset: QinaoEndpointPreset = .roleDefaults
    ) async -> any QinaoOrganEndpoint {
        let registry = BASOrganRegistry()
        await registry.register(adapter)
        switch preset {
        case .roleDefaults:
            return BASOrganRegistryEndpoint(
                registry: registry, providerID: selectedProviderID)
        case .greedyDeterministic:
            return BASOrganRegistryEndpoint(
                registry: registry, providerID: selectedProviderID,
                presetForRole: { _ in .greedyDeterministic })
        }
    }
}
```

- [x] Add tests to the existing identity class using its real InvocationSpy
  adapter; no duplicate dispatcher or concrete runtime. New factory tests
  use only public signatures. Keep all existing package-internal negative and
  ordering tests unchanged. Minimal public-path positive test:

```swift
func testPublicFactoryPreservesEagerAndStreamingIdentity() async throws {
    let spy = InvocationSpy(providerID: "host.selected")
    let endpoint = await QinaoLoop.makeOrganEndpoint(
        selectedProviderID: "host.selected", adapter: spy)
    let response = try await endpoint.produceBody(
        prompt: "input", context: ["context"], role: .scout, sessionID: "s")
    XCTAssertEqual(response.providerID, "host.selected")
    XCTAssertEqual(response.body, "host.selected-eager")
    XCTAssertEqual(response.traceID, "host.selected-eager-trace")
    let streaming = try XCTUnwrap(endpoint as? any QinaoStreamingOrganEndpoint)
    var chunks: [QinaoLoop.OrganResponseChunk] = []
    for try await chunk in streaming.streamBody(
        prompt: "stream", context: ["stream-context"], role: .core, sessionID: "s") {
        chunks.append(chunk)
    }
    XCTAssertEqual(chunks.map(\.providerID), ["host.selected"])
    XCTAssertEqual(chunks.map(\.cumulativeBody), ["host.selected-stream"])
    let calls = await spy.requests()
    XCTAssertEqual(calls.eager.count, 1)
    XCTAssertEqual(calls.stream.count, 1)
    XCTAssertEqual(calls.eager[0].instruction, "input")
    XCTAssertEqual(calls.eager[0].context, ["context"])
    XCTAssertEqual(calls.eager[0].preset, .scout)
    XCTAssertEqual(calls.stream[0].preset, .core)
}
```

  Add `testPublicFactoryUnknownIdentityNeverInvokesAdapter`: selectedID
  `missing`, supplied spy ID `host.selected`; eager and stream both throw
  `LoopError.organUnavailable("unknown-provider:missing")` and both invocation
  arrays remain empty. Add `testPublicFactoryUnsupportedRoleRefusesBeforeCall`:
  scout-only spy, core request, typed `unsupported-role:core`, no invocation.

  Add `testPublicFactoryPreservesGreedyAndRoutedPresets`: factory with greedy
  preset, ordinary core call receives exactly `.greedyDeterministic`; cast to
  `QinaoBudgetAwareOrganEndpoint` and make the existing decision shape with
  core/temperature0.25/maxOutputTokens77/deterministicfalse. The second call
  receives those exact routed values and existing name `qinao.m77.core.routed`.
  Verify both calls stay on the supplied spy and preserve prompt/context.

  Add `testPublicFactoryPreservesCancellationError`: extend the existing spy
  with an optional `cancelRequests: Bool = false`; after recording each eager
  or stream request, this test-only mode throws/finishes with CancellationError
  instead of output. Both public factory paths must preserve CancellationError,
  with one eager and one stream entry, no successful body/chunk or regeneration.
  Keep all existing default spy behavior unchanged; this checks error propagation,
  not cancellation timing or proof that a physical effect was prevented.

  Add `testPublicFactoryDoesNotInventStreamingSupport` using this small eager-
  only wrapper around the existing spy (not another dispatcher):

```swift
private struct EagerOnlyAdapter: BASOrganAdapter {
    let spy: InvocationSpy
    var descriptor: BASOrganDescriptor { spy.descriptor }
    func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
        try await spy.draft(request)
    }
    func currentCapacity() async -> BASOrganCapacity { .unlimited }
}
```

  The returned endpoint's stream must throw `endpoint-not-streaming`, and the
  underlying spy must have zero eager/stream calls. A descriptor's advertised
  streaming flag alone must not cause an eager-generation fallback.

- [x] Establish behavioral RED with the declared factory temporarily returning
  only `BASOrganRegistryEndpoint()`; tests must actually execute and fail before
  forwarding is implemented. A missing-symbol/compiler-only failure is not
  the behavioral evidence. Then implement the complete factory above.
- [x] Run new cases (filter `BASOrganRegistryEndpointIdentityTests/testPublicFactory`)
  to GREEN, then the complete three-class covering filter once:
  `BASOrganRegistryEndpointIdentityTests|QinaoOrganErrorTranslationTests|QinaoOrganRoutingTests`.
  Existing mismatch/error/routing controls remain, with explicit new cancellation
  propagation and non-streaming controls through the public factory itself.
- [x] Run from repository root with known compiler-cache escalation on the
  first attempt. No extra package-wide baseline and no model opt-in flags:

```bash
LOG="$(mktemp /private/tmp/task-27-native.XXXXXX)"
printf 'Retained log: %s\n' "$LOG"
/usr/bin/script -q "$LOG" /usr/bin/env -u QINAO_JOURNAL_GROUND -u QINAO_JOURNAL_GROUND_REPO -u QINAO_JOURNAL_GROUND_SEMANTIC -u BAS_ENDURANCE_AUTOSTART -u BAS_V12_PROBE -u BAS_FUZZ_BENCH_RUN -u QINAO_MLX_E2E -u QINAO_MLX_BENCH -u QINAO_FM_E2E -u BAS_T5_XCTEST -u BAS_AGENT_FABRIC MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib swift test --package-path QinaoRuntimeSDK --build-system native --scratch-path /private/tmp/qinao-sdk-native-test-7806dc5a --disable-automatic-resolution --filter FILTER
```

  Every attempt/retry allocates a fresh log; poll the same live handle to its
  actual terminal exit. Record skips/warnings and failures, not only assertions.
- [x] Save `task-27-report.md` and the frozen two-file `task-27-scoped.diff` with
  SHA-256 in `.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/`. Self-review
  the full scoped diff and run diffcheck; release source/native ownership.
  Root independently reviews and commits only after both verdicts pass.

## Verification and review disposition

The six added tests actually ran against an unconfigured factory and failed
(6 tests, 7 failures), then passed after forwarding was implemented. The final
three-class covering run executed 42 tests with zero failures and zero skips.
Independent review approved product quality, with no Critical/Important code
finding. The frozen two-file diff SHA-256 is
`64ec50df48ccf5d7d8991a52ed12f352c2535a5eea7aff63ab198cee97cbfb3d`.

The checked execution step has a disclosed exception: the first focused GREEN
attempt omitted the required compiler-cache escalation and failed before tests;
a fresh-log escalated retry passed. Review therefore did not certify flawless
process compliance. This historical deviation cannot be repaired by rerunning
unchanged tests. All four attempt logs are retained in the implementer report;
no original is replaced. Successful runs still emit the required native-build-
system deprecation warning; the RED build also had pre-existing compiler warnings.

Ruling: accept the independently approved implementation and actual passing
evidence, while retaining both process/warning observations for whole-branch
review. No product-code fix or duplicate validation is warranted by those
observations; the cost was an unnecessary failed setup attempt. This seam does
not close concrete-provider inversion, shared generation, actual App recovery,
current hosted CI or DS3 readiness.

## Preflight consistency

| Relationship | Check |
| --- | --- |
| Leaf caller / public SDK factory | Supplied neutral adapter and explicit identity, no upward package edge or concrete loader |
| Factory / existing endpoint | Same eager, stream and routed implementation; no eager-only type erasure or alternate lookup |
| Source / tests | Existing spy checks actual input, identity, preset and invocation counts; missing ID refuses before any call |
| Task26 / Task27 | No overlapping product files; only one implementer, native scratch remains idle until Task27 starts |
| This bridge / full product requirement | Concrete file relocation, injected UI and storage-first App owner still need implementation and real fresh-process verification |
