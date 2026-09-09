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
