# Project06 Failed Deep Scan Forensic Recovery

> **Status: `RECOVERED_UNSEALED_AGGREGATE`**
>
> This is a non-authoritative forensic recovery ledger. It is not a successful
> Codex Security scan, not a sealed report, not proof that all repository
> surfaces were covered, and not authorization to remediate any candidate.

## Executive result

The failed Deep Scan did not lose all of its substantive review work. Before
the terminal artifact error:

- ten independent reviews were reported complete;
- semantic reducer pass 8 successfully recorded an aggregate of 56 findings
  and accounted for 104 unique source-finding references exactly once;
- semantic reducer pass 9 successfully recorded an aggregate of 68 findings
  and accounted for 131 unique source-finding references exactly once; and
- the pass-9 record call returned `isError: false`, `findingCount: 68`, and the
  consumed worker ID `3e8830be-62e6-43b1-a325-192aae2a03e5`.

The official scan subsequently failed while resolving an ephemeral
`discovery-0004/output/result.json`. The workbench therefore exposes zero
sealed/indexed findings and no report. Its `findingCount: 0` means “no findings
survived canonical publication,” not “the reviewers found nothing.”

The recovered 68-row index is stored in
`2026-08-28-project06-failed-deep-scan-candidate-index.tsv`; its 452 recovered
source-location references are stored in
`2026-08-28-project06-failed-deep-scan-candidate-locations.tsv`. Exact
SHA-256 identities for all 65 related session records are stored in
`2026-08-28-project06-failed-deep-scan-session-sha256.txt`. The complete
14-coordinator publication inventory is stored in
`2026-08-28-project06-failed-deep-scan-worker-inventory.tsv`. Leads from the
four non-terminal drafts are segregated in
`2026-08-28-project06-failed-deep-scan-incomplete-draft-leads.md` so they cannot
be mistaken for members of the 68-row aggregate.

The recovered aggregate contains 7 high-, 43 medium-, and 18 low-severity
rows. Confidence labels are 64 high and 4 medium. These are recovered reducer
labels, not a fresh security-validation judgment.

## Authoritative failed-scan identity

| Field | Value |
|---|---|
| Scan ID | `3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9` |
| Mode | `deep` |
| Target | `/Users/changgeng/Project/Project06/Project06` |
| Scope | `.` |
| Target revision | `243c083f345f3586ef226020d42af4653b31a62a` |
| Required snapshot digest | `codex-security-snapshot/v1:sha256:4eec62e628394486ca0430b468377a10b234ed0ae8fdbc895603ec0756731467` |
| Scan directory | `/private/var/folders/1x/snst3dq92x998rmwhc2tm09h0000gn/T/codex-security-scans-1K2rWG/Project06/243c083f345f3586ef226020d42af4653b31a62a_20260826T212406Z_riiamvki` |
| Official status | `failed`, phase `discovery`, review pass `9` |
| Official progress | `10` independent reviews complete; `10,347` files total |
| Official output | `0` sealed findings; report unavailable; artifacts empty |
| Failure | `ENOENT` while taking `realpath` of `artifacts/deep_discovery/workers/discovery-0004/output/result.json` |

These fields were re-read from the workbench on 2026-08-28. No resume,
completion, cancellation, or replacement scan was invoked during recovery.

## Recovered publication receipts

### Discovery worker 0004

The coordinator session
`01a03ff5-7a42-7171-972a-f9e578fb1a79` explicitly submitted its terminal
Standard result with `complete: true`. The host returned:

```json
{"scanId":"3d22f697-0c9d-4dbb-8c6a-871a9cfbcca9","findingCount":19,"surfaceCount":24,"operation":"replace","status":"draft_written"}
```

The coordinator then emitted “Terminal Standard scan submitted successfully.”
This proves the host acknowledged a terminal worker publication before the
later read failure. It does not prove the worker payload remained durably
materialized, and it does not elevate those 19 rows to a sealed Deep Scan
report.

### Semantic reducer pass 8

Session `01a0409e-c805-7f72-83b3-8d5698c36dd9`, reducer label
`dedup-0008`, recorded:

```json
{"findingCount":56,"consumedWorkerIds":["3ebbf548-e71b-4e39-9016-1ac321078407"]}
```

The reducer reported 56 retained findings and 104 unique source-finding
references accounted for exactly once, with partial coverage preserved.

### Semantic reducer pass 9

Session `01a040a5-6478-7751-a798-ce69f852efff`, reducer label
`dedup-0009`, loaded one complete 27-finding worker result plus the prior
56-finding aggregate. Its explicit remediation-subsumption map merged 15
same-root worker findings and retained 12 distinct worker findings, producing
68 rows. The terminal receipt was:

```json
{
  "outputFindingCount": 68,
  "outputSourceRefCount": 131,
  "coverageCompleteness": "partial",
  "recordResult": {
    "isError": false,
    "content": [
      "{\"findingCount\":68,\"consumedWorkerIds\":[\"3e8830be-62e6-43b1-a325-192aae2a03e5\"]}"
    ]
  }
}
```

This is the strongest recoverable semantic state. It remains unsealed because
the parent scan never produced canonical manifest, findings, coverage, and
report artifacts.

## Worker inventory and exact aggregate accounting

Discovery coordinators 0001–0010 all reached an acknowledged `complete:true`
publication. Their retained source-finding counts were:

```text
5 + 10 + 11 + 19 + 17 + 13 + 20 + 27 + 2 + 7 = 131
```

That sum exactly equals reducer pass 9's 131 unique source-finding references.
The 68-row aggregate therefore accounts for the ten terminal worker results,
after semantic merging, without an unexplained source-count gap.

Coordinators 0011–0014 did not emit a final message, task-complete event, or
`complete:true` publication. Their last acknowledged `complete:false` drafts
contained 10, 2, 0, and 2 findings respectively. They are preserved as
additional incomplete coverage evidence but are not part of the terminal 131
source references. In 0013, a later six-candidate replacement failed schema
validation and never received `draft_written`.

Direct historical reads prove that temporary `result.json` objects existed for
0001, 0006, 0007, 0008, 0010, and 0011 at intermediate or final points. Every
worker output directory is absent now. Other rows have artifact-service
acknowledgements but no independent historical stat/read, so the ledger keeps
publication acknowledgement separate from final-file durability.

## Evidence ontology

| Tier | Meaning | Present here |
|---|---|---|
| E0 | Canonical sealed scan and report | **No** |
| E1 | Reducer aggregate accepted by the artifact service | **Yes: 68 / 131** |
| E2 | Complete Standard worker draft accepted | **Yes, including missing worker 0004** |
| E3 | Emitted assistant conclusion and tool receipt in session record | **Yes** |
| E4 | Unvalidated lead, deferred surface, or hidden transient thought | Not promoted |

Only E1–E3 are represented in the recovered ledger. Hidden/encrypted reasoning
was neither decrypted nor copied. The recovery used session metadata, emitted
assistant messages, tool-call inputs, tool-call outputs, and repository source
evidence only.

## Root-cause chain

1. Standard workers produced semantic drafts and received artifact-service
   acknowledgements.
2. Serial reducers consumed those drafts, constructed a deterministic aggregate,
   and received a successful artifact-service acceptance response for the
   68-row pass-9 state.
3. A later parent operation still treated each worker’s temporary filesystem
   `result.json` as a required source of truth.
4. `discovery-0004/output/result.json` was absent when `realpath` was called.
5. The parent flattened this recoverable publication/rehydration fault into a
   terminal failed scan with empty canonical artifacts, discarding the already
   acknowledged aggregate from the user-visible result.

The evidence supports a state-split inference: the emitted session records
durably preserve an acknowledgement that the semantic data plane accepted a
68-row aggregate, while the scan control plane still depended on an ephemeral
worker path. Aggregate-payload durability or survival is not established. The
precise deletion actor is not recoverable from the emitted records, so this
ledger does not claim whether cleanup, restart, lease expiry, or another
lifecycle race removed the file.

## Recovery invariants the harness must enforce

1. **A completion counter follows a durable receipt, never worker process exit.**
2. **Worker publication is content-addressed.** Persist `{workerId, digest,
   size, schemaVersion, receiptId}` atomically before acknowledging completion.
3. **Reducers consume durable receipts, not temporary paths.** Temporary files
   are caches only and are always reconstructible.
4. **The aggregate is a first-class checkpoint.** Once reducer pass N is
   acknowledged, reporting can resume from that aggregate without reopening
   every worker file.
5. **Finalization is a two-phase commit.** Prepare and validate canonical
   artifacts, atomically seal their manifest, then publish the report.
6. **Garbage collection is reachability-aware.** Worker outputs remain leased
   until the parent manifest is sealed plus a recovery retention period.
7. **Missing artifacts are typed recoverable faults.** Rehydrate by receipt or
   rerun only the missing review; never erase an accepted aggregate.
8. **Failure preserves partial truth.** The UI exposes the last acknowledged
   reducer checkpoint with an unsealed/incomplete banner instead of presenting
   an ambiguous zero.
9. **Every transition is restartable and idempotent.** A repeated publication,
   reduction, or seal attempt with the same digest must converge on the same
   state.
10. **Crash-injection tests cover every boundary.** Kill/restart before and
    after worker write, receipt, reducer write, manifest seal, report publish,
    and cleanup; assert no accepted state becomes unreachable.

## Relationship to earlier security and P0 work

The repository’s prior durable checkpoint records a successful security
evidence set with scan ID `dd2acd18-3ead-44fa-9c10-f8fd8c911aa7`, evidence
token `59ad886e-6663-4c74-9ac1-b85ec68c1a8e`, evidence digest
`351ad8736ab263b314313e7fd497d21cbd638a93b92fad8811e7b4fd6f82f280`,
10,388 files inspected, and 63 findings (2 medium, 61 low). Its two medium
findings were the pre-existing unbounded ChatCompletions/AsyncBytes buffering
residuals assigned to future W5. The recovered 68-row aggregate contains the
broader same-family row `resource-bounds-not-enforced`; this is an overlap, not
proof that W5 is closed.

Prior conversation state also preserved a separate historical Deep Scan
locator `bcffa52e-53cf-4407-b216-14288ae07061`. Its relationship to the
repository checkpoint above was not re-derived from the surviving pass-9
records, so the two identifiers remain explicitly distinct.

The newer P0 branch
`codex/qinao-dual-space-controlled-convergence` is currently at the later
documentation-closure commit
`29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`. Independent whole-range
acceptance covers `4f0b9846c..d3650dc5e`; it does not extend through the
later documentation commit. The P0 plan states an exact goal of failing closed
at two reachable local-tool execution sinks:

- paired HumanEval generated-code execution; and
- unsafe/unverified model checkpoint deserialization.

Only the paired HumanEval sink maps directly to recovered row
`evaluation.generated-code-unsandboxed`, which is marked closed on the newer
P0 branch but was present in the failed scan’s older target revision. The P0
checkpoint hardening changed the distinct `Tools/mamba3_deploy.py` path; the
recovered row `supply-chain.unsafe-checkpoint-deserialization` instead points
to `scripts/PhaseB_ContextClassifier/convert.py` and `convert_coreai.py`, both
of which still use `torch.load(..., weights_only=False)` at the P0 branch head.
That recovered row therefore remains open for focused revalidation. The P0
acceptance explicitly does not authorize W1, K3/EventLog, ledger, persistence,
or global recovery, so no other recovered row is silently declared fixed.

## Known gaps and limits

- The official scan remains failed and cannot be represented as a completed
  security assessment.
- Coverage was explicitly partial; 68 is not “all defects.”
- The aggregate’s full canonical JSON object was not retained as a sealed
  artifact. The durable recovery preserves its exact row identity, severity,
  confidence, merge accounting, 452 source-location references, and session
  provenance.
- Incomplete 0011–0014 drafts contain additional overlap and deferred leads;
  they remain coverage evidence only and were not silently added to the 68-row
  terminal aggregate.
- The 65 source session files remain external Codex records. Their observed
  bytes are frozen by SHA-256, but this repository does not copy hundreds of
  megabytes of session data or hidden/encrypted reasoning.
- Candidate validity is bound to target revision `243c083f...`. Except for the
  one directly mapped HumanEval P0 closure, current-branch status requires
  focused source validation before remediation.
- No code fix, scan restart, scan completion, or broad replacement run is part
  of this recovery ledger.

## Safe continuation

The next governed move is not a full rescan. First implement and verify the
publication/recovery invariants above. Then validate the 68-row candidate index
against the intended current branch, beginning with high-severity rows and
known overlaps. Only unrecoverable coverage gaps should be rescanned, with
content-addressed receipts and crash-resume tests active before the run.
