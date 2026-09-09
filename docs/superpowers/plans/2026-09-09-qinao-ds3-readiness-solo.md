# Qinao DS3 Readiness — Solo Development Plan

> Continue with ordinary development and focused delegation where useful. This plan supersedes the execution machinery of the 2026-08-29 Tasks1–15 plan; the old plan and its historical results remain preserved. Checked items require actual evidence, not a matching old task label.

**Goal:** 在保留 Qinao 既有工作、Git 历史及 DS1/DS2 真实证据的前提下，解决影响 DS3 准备度的实际问题，完成必要构建、测试、恢复验证、独立代码复核和轻量 PR 整合，交付可复现且没有未处置阻断项的 DS3 就绪版本。不为旧计划的自设控制链额外造系统；不擅自启动 DS3；合并前取得用户对精确候选版本的新鲜批准。

**Architecture:** Normal Git branches/commits preserve code; existing project test tools and read-only CI validate behavior; a concise issue/readiness checklist links each conclusion to source, test and review evidence. No custom development authority, proof-chain service, merge token, per-task registry or replacement harness is required.

**Tech Stack:** Existing Git/GitHub, Python3.9 standard-library tests, Swift/Xcode and Cargo tooling as relevant to actual changed components. Retain dependency locks and practical environment hygiene without freezing every host utility as a development gate.

**Spec / decision basis:** The user's 2026-09-09 confirmation of ordinary Git→necessary tests/review→PR→fresh merge approval, followed by the explicit instruction to optimize the goal and implement it until DS3 can begin. The preserved 2026-08-29 plan supplies historical context and useful requirements, not a mandate to build every proposed mechanism. The newer user-directed outcome governs.

## Global constraints

- Preserve existing commits, worktrees, branches, dirty drafts and evidence. Do not use amend/reset/force-push or delete old work to manufacture a clean result. Optional uncommitted implementation may be deferred only with its exact patch/source/results preserved and its dependencies checked.
- Keep the repository private and use the existing development branch/remote. Excluded private support exports, old drafts, credentials and ignored runtime records are not automatically uploadable.
- All changes to main use a PR. Before merge, show the exact candidate, review/test result and remaining limitations, and obtain a fresh user decision. Ordinary in-scope edits/tests/commits/PR work do not require repetitive task-level approvals.
- DS1 is the first successful scan; DS2 is the later failed scan. Preserve that chronology. DS3 remains not started and requires a separate explicit user authorization.
- A missing original artifact is not a successful reconstruction; a recovered DS2 draft is not a sealed finding. Do not mark an issue fixed from a closed label or unrelated green tests.
- Necessary verification stays: nonempty relevant tests, meaningful review, checks for accidental secrets/destructive changes, dependency integrity, and recovery behavior where retained code promises it. No known blocking defect or critical evidence gap may be hidden in the readiness claim.
- Existing tool/platform permissions remain in force. Do not evade a denied action or widen credentials/network authority under the guise of simplifying repository workflow.
- The last usage reset is reserved for actual exhaustion preventing authorized work; preserve the existing conditional authorization and avoid duplicate redemption.

## Definition of done

1. **Historical scope is reconciled.** A finite checklist distinguishes DS1 original findings, DS2 recovered candidates, independently validated defects and incomplete leads. Each relevant item has an evidence-backed disposition and points to its current component. Still-applicable defects are fixed; unresolved or unprovable items remain explicit. Key evidence gaps or unaddressed blockers mean not ready.
2. **The development state is coherent and recoverable.** Converged history is preserved; retained corrections are reviewed and committed; unrelated drafts remain intact. A restart can locate the current branch/commit, pending work and test results from Git plus readable files, without a task-frontier authority chain.
3. **Verification covers the real changes.** Use focused behavioral tests while fixing defects and an appropriate complete validation set on the final candidate. Record commands, actual counts/outcomes and tested source identity. Repeat only for relevant source/state changes or demonstrated gaps. Report genuine platform/product limitations rather than changing test scope to manufacture success.
4. **The ordinary PR is ready and integrated.** Keep useful read-only CI, retire obsolete active admission/controller requirements, perform independent code review, close actionable findings, push the intended code only, obtain fresh exact merge approval and verify the actual merged result from a fresh checkout. An uncertain remote mutation is observed before retry, without a new custom receipt system.
5. **DS3 has a concrete start target.** Produce one concise readiness report with repository/branch/commit, review/test evidence, issue dispositions, limitations and safe artifact location. There are no unhandled blockers to the proposed scan. The report explicitly says DS3 has not been run and asks for its separate authorization only when ready.

## What carries over from the old Tasks1–15

| Old work | Current disposition |
|---|---|
| Tasks1–3 history preservation/convergence and completed repairs | Preserve actual commits and evidence; do not repeat completed work to obtain new labels. |
| Task4 documentation/fixture correctness | Finish the useful correction. Review the uncommitted revision extension separately; it is no longer required merely to let development continue. |
| Tasks5–7 and10 proposed metadata/evidence/automation/review machinery | Do not build these wholesale just because the old plan lists them. Keep the actual purposes: understandable PR description, change/risk review, known automation/permission checks and no duplicate remote effects. Use existing Git/GitHub functionality and concise records. Add code only for a demonstrated retained requirement, not to satisfy a self-invented proof format. |
| Task8 build/test/dependency work | Preserve necessary tests, reproducibility, locked dependencies and actual recovery checks. Do not construct a new typed executor or per-task authority path as a prerequisite. |
| Task9 CI/workflow cleanup | Retire obsolete active admission requirements, retain history and useful least-privilege read-only CI. Do not silently remove required test coverage or enable unattended writes/merge. |
| Tasks11–13 candidate validation/review/push/PR | Perform ordinary coherent-diff review, relevant tests, privacy checks, safe push and one PR. Custom host snapshot digests, comment chunk protocols, exhaustive invisible-grant proofs and repeated evidence-post reapprovals are not independent deliverables. |
| Task14 exact human merge decision | Retained. No old approval or successful machine check substitutes for it. |
| Task15 merged-result/recovery verification | Retain fresh checkout/result verification and necessary postmerge checks. Remove phase/frontier ceremony, not verification of the actual result. |

Existing historical readers/controllers are not deleted automatically. First determine whether a real current consumer needs them; preserve compatible history access or defer unused changes without losing their source. The goal is not to replace one controller with another.

## Current implementation order

- [x] Record the user-approved solo-workflow change and preserve the old plan.
- [x] Finish the already-running correction regression without interruption: actual36tests/570.221s/exit0 on the frozen source below. This is focused evidence, not whole-repository readiness.
- [x] Independently review the two-file diff and retain only the necessary fixture repair. The optional uncommitted task-revision extension and results are preserved; no actual historical task-revision record or committed consumer depends on it. Fresh fixture-only verification passed21tests/202.619s/exit0.
- [ ] Reconcile the existing DS1/DS2 source records and prior closure evidence into the finite readiness checklist. Do not start a new scan or recreate missing canonical artifacts under a misleading name.
- [ ] Complete actual remaining fixes and the ordinary CI/documentation cleanup, with focused tests and scoped review. No per-task control-chain publication is needed to begin the next edit.
- [ ] Run the appropriate final validation/review set, commit the intended work, push the current development branch and open/update one lightweight PR.
- [ ] Obtain fresh exact merge approval, perform the authorized merge, verify its actual result and publish the DS3 readiness report. Do not start DS3.

## Concrete starting evidence

- Working tree: `.worktrees/qinao-git-only-convergence`; branch `codex/qinao-git-only-convergence`.
- Current committed candidate: `d41cfdbd4e6cbf5ec8e3a7d604ea4d59e136ce82`, tree `5974036be4cae9f60a81c7e367cd051b38b9c3e0`; this development ref was already uploaded, not merged.
- The optional uncommitted extension's audit SHA256 `b75e23899e41b8a8dafd60cc25fe37d963344b4984cdbd6fb543652a3e6745a3` and tests SHA256 `4d1ced1c96bf33953dec7d967757e23d0694f15156e9437a778202fbd301841b` are retained as source copies/full diffs/results in `.superpowers/sdd/2026-08-29-qinao-git-only-convergence-and-lightweight-pr/`, not active source. Independent review approved the fixture-only correction and identified a malformed `observedPriorCandidate` defect in the deferred extension.
- Active fixture-only audit SHA256 `55df3a040abc0f9fa44bce155969043920004356d719f2dc9fda60e9d87f8af8` equals the committed production source; tests SHA256 `960e0a1792797fcd5dab9c4938b787113bee639f8bc3c4b7fce5fbcc672c6943`. Fresh21tests/202.619s/exit0. Both handles35012 and39548 are terminal; never poll/restart them. Full invocation and result: `task4-solo-fixture-only-handback.md` in the preserved SDD directory.
- DS1 index observation: `docs/superpowers/evidence/2026-08-28-project06-deep-scan-1-index-observation.md`; scan `bcffa52e-53cf-4407-b216-14288ae07061`,111 indexed occurrences. On2026-09-09 all111 official indexed finding details and the exact111 stored details_json strings (6,453,105 original bytes) were exported read-only into the new plan's private SDD workspace. Canonical documents remain unreadable; this is labeled noncanonical recovery and does not establish current issue closure.
- DS2 recovery: `docs/superpowers/evidence/2026-08-28-project06-failed-deep-scan-forensic-recovery.md` and associated candidate/lead inventories; scan `3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9` remains failed,68 recovered aggregate candidates are unsealed.
- Current GitHub CLI identity was successfully checked on2026-09-09 as `ChangGeng01`; the old planning-time invalid-credential statement is not a current blocker. Recheck the actual permission relevant to each consequential operation when needed.

## Goal tracking limitation

The app's available goal API can read the objective or mark complete/blocked, but cannot edit an active objective's text. The UI-control surface also refuses access to Codex. Therefore the old goal card text/accounting remains intact; this user-requested updated plan is the active execution definition. Do not mark the unfinished goal complete just to recreate its text, reset its usage history, or manipulate app storage. Completion is judged against the full updated outcome above, not against the amount of work already done.

## Task 1: Correct the supported auxiliary evaluation report

This is a bounded ordinary fix within historical reconciliation, not revival of old Tasks1–15. Base: b36036895214a347abb3d52fa30acd5518d9745e. The historical DS1 release-verdict aggregate is broader than this specific reporting defect; do not close the whole aggregate from this patch.

**Invariant and supported behavior:** `release_gate.py` must not present a partial evaluation as full release readiness. Keep the operator-invoked CLI and output filename compatible, preserve meaningful partial evaluation results and visible pending requirements, and retain conservative release exit semantics. No repository deployment/merge consumer was found; external consumers are unknown. Plaintext logs/metrics remain observations, not authenticated or necessarily fresh evidence. This tool must not become merge authority.

**Authorized files:** `BehavioralAISubstrate/Tools/qinao_local_eval/release_gate.py`, its tests in `Tools/tests/test_release_gate.py` and `qinao_local_eval/test_release_gate_keys.py` as needed, and a concise correction in `qinao_local_eval/README.md`. Read `build_verdict.py`, its relevant tests and the release checklist for compatibility; do not change the builder, generic merge, HumanEval evidence boundary or unrelated producers.

**Required correction:**

- Separate the computable combined result as `evaluation_ok`; retain `release_ok` as false whenever the stronger model release result or any model/substrate critical requirement is pending. There is currently no implementation that supplies the two deferred substrate checks, so current reports cannot attest full release readiness. Do not add a channel, signature, authority, registry or user-supplied override to make it green.
- Make JSON, printed labels, documentation and CLI status agree: partial pass is useful but is not `RELEASE_OK=True`; keep the CLI nonzero when full release requirements remain unverified. Preserve `build_verdict.py`'s distinct zero-for-successful-report-generation behavior.
- Validate the model JSON structures consumed by this report; reject malformed top-level/row/deferred shapes with an explicit unavailable reason rather than crashing or treating truthy strings/numbers as Boolean success. Boolean fields pass only for actual JSON true. Retain valid builder-produced documents and regression/contamination row behavior.
- Resolve the substrate package relative to this script, not another hard-coded checkout. Honor an explicit log argument/environment path: an unreadable/missing requested log must report unavailable, never silently launch a different run. For the fallback test command, a nonzero process result must not be accepted because its partial log contains passing counts. This remains a trusted local tool invocation, not an attempt to defend an already compromised host.
- Preserve existing parsing/key extraction and relevant auxiliary checks. Do not silently remove partial-result diagnostics, critical requirements or legitimate test coverage.

**Verification:** Follow TDD with a focused failing combined-report case and legitimate partial-pass control before implementation. Cover pending model/substrate requirements despite all computed passes, malformed Boolean/JSON shapes, candidate-local checkout, explicit missing log without subprocess launch, and nonzero subprocess with apparently passing output. Use isolated temporary fixtures and no real model downloads, external report overwrites or Swift invocation. Run the two named release test modules and directly relevant builder/generic-merge compatibility tests; record actual counts, outputs, skipped checks and diff check. Root arranges one independent bypass/regression review and commits only after handback. No staging, commit, push, scan or subagents in this implementation.

## Task 2: Restrict both context-classifier checkpoint loads

Base1329bde36b5351e2bf59a570ddafd4dda25a6580. Existing DS2 candidate `supply-chain.unsafe-checkpoint-deserialization` (candidate index and locations TSV, row25) identifies exactly `BehavioralAISubstrate/scripts/PhaseB_ContextClassifier/convert.py` and `convert_coreai.py`. Root and a read-only independent investigator traced both main entrypoints and the local trainer's save format before this amendment.

**Invariant:** Checkpoint bytes are data, not permission to execute arbitrary Python. Both conversions must load with explicit `weights_only=True`, CPU mapping, no unrestricted retry or checkpoint-selected allowlists. A shared small sibling loader is appropriate for enforcing the same rule in both entrypoints; no Mamba identity/signature/snapshot framework is required for this separate boundary.

**Dependency floor:** Enforce PyTorch>=2.10.0 before either call to torch.load, rejecting older, malformed or unverifiable versions and prereleases below the final floor. Use proper PEP440 ordering (public packaging.version), not lexicographic/TorchVersion fallback or a homemade parser. Document the dependency explicitly. Official PyTorch advisory GHSA-63cw-57p8-fm3p reports restricted-loader code execution through2.9.1, patched2.10.0; GHSA-53q9-r3pm-6pq6's older2.6.0 floor alone is insufficient. Root re-read both primary advisories on2026-09-09. This is protection from the cited known flaws, not a guarantee against every future PyTorch vulnerability.

**Compatibility:** Preserve checkpoint/output locations, missing-dependency/missing-checkpoint behavior, locally reconstructed architecture, dimensions/labels/state_dict and conversion/backend behavior. train.py205–214 saves only a tensor state_dict, integer dimensions/seed and labels; custom classes are not part of the supported format. Keep standard local-version metadata compatible. Do not train, download models, run real conversion/Apple compilation, overwrite existing assets or modify the trainer. If a real dependency conflict is established, report it rather than weaken restricted loading/version floor.

**Authorized files:** The two converters, one small shared sibling checkpoint helper, one focused test module, and this directory's README/dependency instructions. No other loader or runtime redesign. Root owns plan/recovery records and commits.

**Tests:** Use real installed PyTorch2.12.0 from the main checkout's existing `BehavioralAISubstrate/scripts/PhaseB_ContextClassifier/venv` if its interpreter works, and stdlib unittest for new tests to avoid installing an unrelated test framework into that environment. Inspect availability first; do not change external environments without the normal scoped permission. Temporary trainer-shaped checkpoint inputs must traverse each actual main; mock only conversion backends/output sinks so no real assets are generated. Test a valid tensor/primitive document, harmless reducer-marker rejection in ZIP and legacy non-ZIP formats, unsupported-loader failure with exactly one restricted call and no retry, explicit True despite TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD, and old/floor/prerelease/malformed version rejection before load. Preserve observed calls/arguments and successful valid path. Any unavailable dependency/real CoreAI compatibility remains explicit, not counted as passing.

**Delivery:** TDD red first, then narrow implementation, inspect exact diff, run relevant nonempty tests with actual complete outputs and counts. Source identity and logs go in this plan's private SDD report. Root will arrange a fresh independent bypass/regression review. No staging/commit/push/scan/subagents or other source edits.

**Post-review verification amendment:** The frozen patch passed its seven real-PyTorch tests and the fresh static reviewer found no concrete bypass/regression, but real Apple-backend compatibility was not established by stubbed backend tests. Root therefore extends verification only: run both unchanged main entrypoints with disposable trainer-shaped inputs and real conversion backends, direct outputs exclusively into temporary directories, inspect output structure and numeric parity where supported. Existing assets/environments must not be overwritten. A new isolated temporary environment may install source-verified fixed official dependencies through normal permissions; do not weaken the PyTorch floor to resolve a dependency conflict. Preserve backend/platform limitations separately from checkpoint-boundary tests. This amendment overrides the earlier no-real-conversion test restriction for this bounded verification, not the no-training/no-model-download/no-asset-overwrite rules. No implementation ownership is delegated by this amendment.

## Task 3: Bound remote Chat Completions receipt and lossless streaming

Base7806dc5a57e97162b339b6bdffac1be8060de8b2. Existing DS1 occurrence
occ_0335bc4ba9b93ef6ecf90884 is statically confirmed in provider-response-triage.json.
Root and a fresh independent investigator read the actual entrypoints, protocol,
host caller and tests. The explicit hostile/misconfigured-peer resource promise
is at BASChatCompletionsOrganAdapter.swift64-67; no SECURITY.md applies.

**Scope:** both files in `BehavioralAISubstrate/Sources/BASChatCompletionsAdapter/`,
one focused adapter-local bounded-response helper, the existing
`BASChatCompletionsOrganAdapterTests.swift` and `BASChatCompletionsStreamingTests.swift`,
and one focused response-boundary test file if needed. Root owns plan, reports,
commit and candidate review. Do not change BASOrgan public protocol/models,
registry routing, provider defaults, other transports, unrelated tests or assets.

**Required boundary:** all received HTTP body bytes are charged before the
adapter retains them, including ignored SSE frames/delimiters/metadata. The
existing maxResponseBytes is also the raw response budget, not merely decoded
content; document this intentional stricter treatment of formerly uncounted
framing. Keep the decoded-content cap and check before cumulative append using
overflow-safe subtraction. No silent truncation, dropped/coalesced deltas,
unbounded chunk/Task queues or cumulative snapshot producer buffer.

**Chosen narrow strategy:** use the injected URLSession's ordinary dataTask with
a request-local URLSessionDataDelegate. In synchronous didReceive(data), check
the monotonic total and append only within budget into one bounded Data buffer;
do not first enqueue Data in Task/actor callbacks. A cursor can expose incremental
consumption; no complicated compaction protocol is required. Prefer retaining
Foundation's existing line semantics via `.lines` on this already bounded byte
sequence instead of inventing a subtly different SSE parser. The public stream
uses AsyncThrowingStream(unfolding:) (or an equally small proven lossless
consumer-driven equivalent), yielding exactly one next nonempty delta with its
correct cumulativeBody. Nonstream collects at most the bounded body before the
unchanged response parser. Raw receipt enforcement continues even when a
consumer pauses; simply changing data(for:) to bytes(for:) is insufficient.

Set task.delegate before resume. The installed SDK documents that it cannot be
changed after resume, is not supported on background sessions, is retained until
completion, and unimplemented methods fall through to the session delegate.
Do not mutate a running task's delegate, create/invalidate the injected session,
or intercept authentication/redirect/cache policies unnecessarily. Preserve
supported injected-session configuration/URLProtocol behavior. Report unsupported
background-session compatibility explicitly instead of crashing or pretending
the delegate is applied.

**Lifecycle:** one optional absolute request.deadline covers headers, idle body,
and pending consumption through producing the terminal response. Do not add a
default deadline when nil or restart a relative timeout on each read. A timer and
explicit owned-task cancellation must wake a pending waiter, even before headers
or waiter registration. Normal network completion is distinct from consumption
of buffered final bytes. Keep the deadline active until final delivery/EOF or
[DONE]; check after synchronous parsing and before returning/yielding as well.
Cancellation/overflow/HTTP rejection/[DONE]/abandonment must stop only this task.
Use a small independent stream owner or equivalent to break receiver↔task cycles;
deinit on a cycle is not cleanup. Exactly one terminal outcome wins; cleanup must
not replace a size/deadline failure with a later URLError.cancelled or erase a
completed [DONE] success. Do not invoke continuations, handlers or task.cancel
while holding state locks. Avoid data races when callbacks/waiters compete.

**Compatibility:** preserve request/model/auth/custom headers, endpoint/role
checks, HTTP error vocabulary and public return types. Keep parser helpers:
malformed/comment/role-only/empty SSE produces no delta; EOF without [DONE]
succeeds and processes a final unterminated line; retain Foundation's supported
newline/UTF-8 splitting behavior. Do not import the vendored EventSource parser
which joins multiline data and changes semantics. Preserve exact bodyDelta and
cumulativeBody (BASStreamingOrganAdapter.swift19-28,50-55). Nonstream maps transfer
errors to transport:...; streaming historically maps startup errors but lets
body-read errors escape—preserve this distinction unless root explicitly rules
on a demonstrated incompatibility. Retain buffered valid-prefix streaming output
before a later transport error where the existing path would emit it. HTTP
non-2xx is rejected on headers before accepting body; actual received bytes,
not Content-Length alone, enforce the size limit.

This bounds adapter-owned body/line/output state to O(cap), not a precise cap on
Foundation's opaque network buffers, allocation growth or one delivered callback
argument. Do not claim a new OS-level memory quota or build a new HTTP stack.

**TDD and verification:** first add an incremental offline URLProtocol fixture
driving both real entrypoints, with small scheduled chunks and cancellation
observations rather than a giant preallocated payload. Show at least one failing
oversized-receipt/deadline/queue case and a legitimate control before production
edits. Cover exact raw cap/cap+1, unterminated line, ignored/malformed/metadata and
empty frames, many tiny frames, split Unicode/newlines, final EOF/[DONE], paused
consumer preserving deltas, deadline before headers/during idle receipt/paused
consumption, transport-error prefix, and cleanup on failure/cancel/abandonment.
Test injected-session policy behavior. Small pure state tests may supplement but
must not replace actual entrypoint/URLProtocol checks. Avoid network access,
real provider credentials, real user data or model downloads.

The completed native BAS build provides reusable scratch
`/private/tmp/qinao-bas-native-test-1329bde3`, with Xcode-beta27 and real same-source
MLX_METAL_PATH `/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib`.
No process owns it now. Run focused relevant XCTest selectors under
`swift test --package-path BehavioralAISubstrate --build-system native --scratch-path ... --filter ...`;
record selected counts and full output. Do not use the headless wrapper or claim
unrelated tests passed. Root's earlier unfiltered baseline had10 assertion
failures in journal CLI discovery/W0 provider-default tests; those remain separate
open work and do not authorize removing coverage. Root will perform the later
coherent full-candidate validation; do not wastefully rerun the whole suite after
each edit. Freeze final diff/source/test logs in this plan's SDD workspace and
return for fresh independent bypass/regression review. No staging/commit/push,
new scan, subagents, system-toolchain edits or other source writes in this task.

## Task 4: Locate the real journal CLI in the current test build

This is the finite test-only repair diagnosed by the actual native BAS run at
1329bde3 (Swift sources unchanged through7806dc5a). The built BASJournalCLI exists
beside BehavioralAISubstratePackageTests.xctest in the external scratch products
directory. Three suites search only working-directory .build paths; throwing
XCTSkip from run() inside XCTest assertions also generates assertion failures.
The baseline is retained in native-bas-full-test-1329bde3.log; do not repeat the
whole suite to rediscover it. Begin only after Task3 hands back source ownership.

**Files:** Modify only the three suites under
`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/`:
`BASJournalCLIIntegrationTests.swift`, `BASJournalGroundingIntegrationTests.swift`,
`BASBetCommitIntegrationTests.swift`; add one small macOS-only shared test helper
and its focused locator tests if necessary. No CLI/product/package/toolchain
edits, binary copying/symlinks, PATH override, fake end-to-end executable, or
unrelated test changes. Preserve all32 existing integration cases and assertions.

**Interface:** The shared test-only locator consumes the actual test bundle URL
and a working-directory URL and returns an executable regular CLI URL or nil.
Prefer the sibling of the actual test bundle before compatible old .build paths:

```swift
static func binaryURL(testBundleURL: URL, workingDirectory: URL) -> URL? {
    let sibling = testBundleURL.deletingLastPathComponent()
        .appendingPathComponent("BASJournalCLI")
    let legacy = [".build/debug/BASJournalCLI", ".build/release/BASJournalCLI",
                  ".build/arm64-apple-macosx/debug/BASJournalCLI",
                  ".build/x86_64-apple-macosx/debug/BASJournalCLI"]
        .map { workingDirectory.appendingPathComponent($0) }
    return ([sibling] + legacy).first { url in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: url.path)
    }
}
```

Each suite obtains Bundle(for: Self.self).bundleURL and resolves once in
setUpWithError(), using XCTSkipIf for a genuinely absent product BEFORE assertion
bodies. Store the resolved URL for run(); a missing setup invariant in run()
must be a normal assertion/error, not a nested skip. Keep process arguments,
disposable journal locations, fixture Git repositories and existing environment
handling unchanged. Do not introduce a base-class hierarchy or process framework.

- [x] **Step 1 — focused RED:** Add a discovery regression to the existing journal
  suite against its existing cliBinaryURL(), asserting the actual same-build
  sibling URL is found when the external scratch holds the real executable.
  The exact expected URL is
  Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
  .appendingPathComponent("BASJournalCLI"). Run that one case in the authorized
  native scratch before changing the locator; inspect the assertion failure,
  not a compile error or a skipped test. Preserve the run output.
- [x] **Step 2 — narrow repair:** Add the shared locator with the interface above
  and migrate all three suites' setup/run access. Add temporary-filesystem unit
  cases for same-build sibling preference over an existing legacy candidate,
  each retained legacy fallback, absent product, nonexecutable file and directory
  rejection. These fixture files test discovery only and are never executed as
  the CLI. The integration discovery regression must still assert the actual
  executable path, not merely a helper's candidate list.
- [x] **Step 3 — real verification:** Run the locator suite AND all three complete
  integration suites, with unchanged actual BASJournalCLI built by the same
  package. Use Xcode-beta27, --build-system native and the handed-back scratch
  /private/tmp/qinao-bas-native-test-1329bde3 with the real matching MLX_METAL_PATH
  documented in Task3. Record the exact command, selected/executed/skipped counts,
  full output, actual executable URL and source identity. All32 existing cases
  must execute rather than newly skip; report actual newly exposed product
  failures for a separate bounded diagnosis, never loosen their assertions.
- [x] **Step 4 — handback:** Inspect diff/check, freeze source/test evidence and
  report to task-4-report.md in this plan's private SDD workspace. Root arranges
  fresh task review and the ordinary commit. No staging/commit/push, subagents,
  new scan or full-package rerun inside this implementation.

## Task 5: Bind registry invocation to an explicit provider identity

This is one ordinary product-correctness slice from the real BAS native failure
`BASProviderBoundaryTests.testRegistryResolvesOnlyAnExplicitProviderID`, not the
whole July Silicon Task7 and not a new security scan. Start after Task4 review
and source handback. The unchanged registry/endpoint baseline is397833fa.
The two full Qinao failures, MLX production-default mismatch and shared-operation
prerequisites remain separate work. This task must not claim to close them.

**Consumes:** `BASOrganAdapter.descriptor.providerID`, existing registry
registration and descriptor presentation, and the actual wrapped adapter already
constructed by each current host factory. No UUID, registration-order winner,
role preference or matrix recommendation becomes the selected provider identity.

**Produces:** exact `BASOrganRegistry.adapter(providerID:)` and
`descriptor(providerID:)`, plus a pinned identity used by both real eager and
streaming `BASOrganRegistryEndpoint` invocations. The registry becomes a lookup,
not an election mechanism. This is not durable provider-execution ownership.

**Production files:**

- `BehavioralAISubstrate/Sources/BASOrgan/BASOrganRegistry.swift`: exact lookup;
  retain registration, replacement, removal, descriptor order/count and read-only
  `hasRole`. Preserve the Codable `RegistryError.noAdapterForRole` case for old
  serialized errors, though lookup no longer generates it.
- `BehavioralAISubstrate/Sources/BASOrgan/BASProviderRouting.swift`: remove the
  now-unconsumed election policy after migrating its callers. Do not remove
  `BASNeuralProviderMatrix` or its pure observation/ranking capabilities.
- `QinaoRuntimeSDK/Sources/QinaoLoop/BASOrganRegistryEndpoint.swift`: explicit
  constructor binding and one shared resolver for eager/routed/streaming calls.
- `QinaoRuntimeSDK/Sources/QinaoMLX/QinaoMLXEndpoint.swift` and
  `Sources/QinaoAppleFoundation/QinaoAppleFoundationEndpoint.swift`: pass each
  already-wrapped organ's exact descriptor ID. Preserve all model choices,
  loading, prewarm, presets, error behavior and wrapper identity forwarding.
- `QinaoRuntimeSDK/Sources/QinaoSampleHost/MultiTurnDemo.swift`: carry the actual
  selected adapter ID into its existing endpoint, without changing explicit
  demo fallback labels/behavior.
- `QinaoRuntimeSDK/Sources/QinaoSampleHost/PersonaPanelReviewDemo.swift`: hold
  the adapter it just constructed directly instead of electing it by role.

**Test files:** BAS tests `BASProviderBoundaryTests`, `BASOrganRegistryTests`,
`BASMultiProviderRegistryTests`, `BASProviderRoutingTests`,
`BASNeuralProviderMatrixTests`, `AppleFoundationOrganAdapterTests`,
`AppleFoundationE2ETests`, `BASChatCompletionsOrganAdapterTests`; Qinao tests
`QinaoOrganErrorTranslationTests`, `QinaoOrganRoutingTests`,
`QinaoLoopGenerationTests`, `QinaoProviderBoundaryTests`,
`QinaoAppleFoundationE2ETests`, `QinaoAppleFoundationPathBE2ETests`,
`QinaoAppleFoundationAIReviewerSimulationE2ETests`,
`QinaoAppleFoundationAIPersonaSetE2ETests`, `QinaoMultiTurnEndToEndTests`,
`QinaoAppleFoundationFactoryTests`, and one focused endpoint-identity test file
if necessary. Test files live under each package's existing test target.
Unlisted concrete caller migrations require a narrow source reference and root
coordination, not a repository-wide redesign. No Task4 file changes.

- [ ] **Step 1 — reproduce the specific existing RED.** Run only
  `BASProviderBoundaryTests/testRegistryResolvesOnlyAnExplicitProviderID` in the
  handed-back native BAS scratch. Its existing protocol probes compile before
  and after the API migration and must report the actual missing-ID/role-election
  assertion, not a build failure. Preserve that output; do not repeat the full
  BAS or Qinao baselines. The test's no-role-API assertion remains unchanged.
- [ ] **Step 2 — exact registry lookup and controls.** Implement:

  ```swift
  public func adapter(providerID: String) throws -> any BASOrganAdapter {
      guard let entry = entries[providerID] else {
          throw RegistryError.unknownProvider(id: providerID)
      }
      return entry.adapter
  }

  public func descriptor(providerID: String) throws -> BASOrganDescriptor {
      guard let entry = entries[providerID] else {
          throw RegistryError.unknownProvider(id: providerID)
      }
      return entry.descriptor
  }
  ```

  Remove both role-selected `adapter(for:)` overloads and routing execution.
  Rewrite obsolete election assertions as explicit-ID behavior or direct matrix
  observations; keep register/re-register/remove/count/order/capability tests.
  Add these concrete assertions with the existing deterministic adapter:

  ```swift
  let registry = BASOrganRegistry()
  await registry.register(BASOrganDeterministicAdapter(providerID: "provider-a"))
  await registry.register(BASOrganDeterministicAdapter(providerID: "provider-b"))
  let selected = try await registry.adapter(providerID: "provider-a")
  XCTAssertEqual(selected.descriptor.providerID, "provider-a")
  let descriptor = try await registry.descriptor(providerID: "provider-a")
  XCTAssertEqual(descriptor.providerID, "provider-a")
  try await registry.unregister(providerID: "provider-a")
  do {
      _ = try await registry.adapter(providerID: "provider-a")
      XCTFail("missing selection must not fall back to provider-b")
  } catch BASOrganRegistry.RegistryError.unknownProvider(let id) {
      XCTAssertEqual(id, "provider-a")
  }
  ```

  Repeat with reversed registration order; test descriptor missing-ID and
  replacement preserves presentation order. Add legacy error Codable round-trip
  coverage without retaining executable role election.
- [ ] **Step 3 — real endpoint binding and call-site migration.** Configured
  registry initializers require `registry: BASOrganRegistry, providerID: String`;
  test-override initializers require an expected `providerID: String` alongside
  the existing role-taking override closure. Preserve `init()` solely for the
  typed `no-endpoint-configured` negative path, with no inferred selection.
  Preserve existing presetForRole/nextRequestID injection in configured forms.
  A single resolver serves eager and streaming paths and enforces:

  ```swift
  // After exact lookup or the explicitly bound fixture override:
  guard adapter.descriptor.providerID == providerID else {
      throw QinaoLoop.LoopError.organUnavailable(reason: "provider-identity-mismatch")
  }
  guard adapter.descriptor.supportedRoles.contains(internalRole) else {
      throw BASOrganError.unsupportedRole(internalRole)
  }
  ```

  Missing exact ID retains `unknown-provider:<id>` translation. Unsupported role
  and provider errors retain existing reason-code grammar; the old Codable error
  still translates if explicitly injected. No failure selects another adapter.
  Factories bind `organ.descriptor.providerID` after their existing wrap; no new
  model selection or fallback is permitted. Migrate every listed real/test caller
  to an explicit ID or an already-held adapter. Do not change response transport,
  buffering, provider metadata format, canonical generation, or default models.
- [ ] **Step 4 — prove invocation, not just lookup.** Add an actor spy with a
  nonisolated immutable descriptor and separate eager/stream invocation counters,
  yielding deterministic nonempty content. Register A and B in both orders and
  bind A. Exercise legacy eager, decision-aware eager and streaming; assert A's
  corresponding counters and zero B calls, exact returned provider ID/body and
  unchanged role/preset request fields. Register later on-device/certified B:
  same result. Remove A with B present: exact unknown-A and zero B calls for
  eager and streaming. Select scout-only A for core: typed refusal and neither
  adapter invoked. Inject B under expected A: identity mismatch before either
  invocation in both paths. Keep no-endpoint, non-streaming and translated-error
  controls. Never use a real model, provider credential or live network.
- [ ] **Step 5 — focused verification and handback.** Use Xcode-beta27 and the
  real matching MLX_METAL_PATH from Task3. BAS scratch is
  `/private/tmp/qinao-bas-native-test-1329bde3`; Qinao scratch is
  `/private/tmp/qinao-sdk-native-test-7806dc5a`. The sole implementer owns both;
  do not run builds simultaneously. Compile all test sources as normal, then
  run the changed registry/matrix/endpoint/error/loop-generation/factory suites
  and the exact BAS identity boundary test. Record exact selectors, executed,
  skipped and failure counts, full logs, source/diff identities and diff check.
  Platform-opt-in E2E tests remain explicit skips; do not activate them. The
  unrelated BAS model-default and two Qinao ownership failures remain open and
  must not be removed, loosened, or counted passed by selectors excluding them.
  Search the named package sources/test call sites to ensure role lookup only
  remains in the deliberate W0 absence probe; successful compilation alone may
  accidentally bind that test-only fallback. Freeze complete patch, logs and
  task-5-report.md for fresh independent task review. No staging/commit/push,
  subagents, new scan, full-suite rerun, dependency/toolchain mutation or cleanup
  of historical files inside this task; root owns review, commit and upload.
