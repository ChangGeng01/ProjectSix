# Local-only automatic router fallback — focused validation

Date: 2026-09-09. Task 9 of the solo DS3-readiness plan.
Base: `0ca8dbf3515b5b705a66bb13123a4201620ae52d`.
Status: accepted after scoped review, one fix round and independent post-fix
verification. Both Important review findings are addressed; no new
Critical/Important breakage. This is not a DS3-readiness or full-recovery claim.

## Retained behavior

The router defaults to `primaryOnly`, with immutable strategy. Its one
construction-time eligibility decision permits explicitly configured automatic
fallback only to a secondary declaring on-device execution. Plain, accelerated
and purpose-based calls preserve the original failure when fallback is
ineligible. Cancellation and non-infrastructure errors never select secondary.
Capacity checks also avoid a held remote; capabilities describe reachable
providers, including nested routers, without changing composite identity.

This implements the user's no-cloud/PCC-on-local-failure rule at this router
boundary. It adds no approval override, retry loop, provider swap by default,
permission service, model call or persistence subsystem. Explicit local
fallback and direct primary/secondary library selection remain available.
Strategy case names and Codable representation remain compatible; callers
that previously reassigned `strategy` must construct a replacement router.

## Actual evidence

The first regression ran before production edits: build succeeded, then one
test failed in the two expected ways — a remote result was returned and the
remote spy count was one instead of zero. Test exit 1, log-writer exit 0.
The earlier sandbox cache-access failure was infrastructure, not behavioral RED.

The final implementation passed 48 focused tests with no failures or skips:
34 router, 6 prompt-wrapper, 3 contracted-wiring, 2 registry-hash and 3 enum
round-trip controls. Root independently reran the same selection after the
review-fix handback: 48 passed, 0 failed, 0 skipped; test/log-writer exits both 0.
The tests use fake adapters; no live local/cloud/PCC provider or user store ran.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib \
swift test --package-path BehavioralAISubstrate \
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 \
  --build-system native \
  --filter 'BASRoutingOrganAdapterTests|BASPromptLookupElectTests|BASContractedWiringIntegrationTests|BASRegistryFrozenHashTests|BASChapter641CategorizationEnumTrioProofTests'
```

Root used Bash pipefail and separately checked both pipeline exits. Complete
RED, implementation GREEN, root verification and review artifacts are retained
under the private `.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/`
directory; raw support exports are not uploaded as part of this change.

The initial independent review identified a stale public enum-case comment
and repeated error-classification blocks. The original implementer corrected
the comment and extracted one private decision helper; each overload retains
its exact forwarding and original-error propagation. The covering 48 tests
passed again, followed by a clean independent fix-only re-review and root's
fresh final-source 48-test verification. The original behavioral RED and
pre-fix records remain preserved; no new RED is claimed for the refactor.

| Artifact | SHA-256 |
|---|---|
| Final router source | `c624deebf7de90b5d198441ccee8ba88394f97f7cb240fbd50917cce2b07e788` |
| Router tests | `ba5e3cc31e91e8676b87d456f8238afaba7f21413fca63619a7d591faf4b1780` |
| Original two-file review diff | `d17e6ba0b185a79af875903224f6a5fa4db8d4189617016b2729910c4aa01713` |
| Fix-only review delta | `92eebfbf2891abdfe792d951fe39a8144c95de45de39dbb8f80b5f5bb6e91322` |
| Behavioral RED log | `3b0a507d0f9bb1899370ec51d718d55c3875aba2789276ae06aaaefe802f18c8` |
| Final implementation GREEN log | `7ea31fea725580fe34cafac19f7b7c3cf9a2fcb4272d237aa849c8e9bb72b0e7` |
| Final independent root log | `f1cbfcad0439c794bbab07e158975e3d6c009fc4d19b13bc63dccac7d5ffb1cd` |

## Limits and remaining work

Eligibility trusts `descriptor.runsOnDevice`; it is not platform attestation
or a sandbox against a dishonest provider. Direct remote selection is not
permission for an operation owner to resume failed local work remotely.
That owner/restart policy still needs its separate implementation and tests.
Infrastructure errors do not establish that generation never began; this
patch does not guarantee exactly-once execution, restore hidden model state,
or establish that a real model outage exists.

Four pre-existing warnings in unrelated device tests appeared in the worker
build; the retained native-build-system deprecation appeared in both worker
and root output. No changed-file warning was reported. The full candidate
baseline and the existing DS1 consent aggregate are not closed by this focused
result. DS3 remains unstarted and requires separate user authorization.
The review also recorded non-blocking repeated fixture setup in the expanded
router test matrix; that remains visible to final whole-branch review.
