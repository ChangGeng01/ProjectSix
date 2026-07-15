# Mirror-Lane / Convergence Charter — operator rulings (2026-07-12)

Three operator rulings (recorded verbatim, translated inline) settle the open questions
from the Qinao integration campaign (QinaoRuntimeSDK/Docs/QINAO_INTEGRATION_CHARTER
_2026-07-12.md) and The Ledger increment-2 design:

## Ruling ① — Convergence lives in BASHostKit

> 汇合管线落 BASHostKit,不落 QinaoRuntime。BASHostKit owns convergence; QinaoRuntime
> only consumes converged signed proposal envelopes. 不提前击发 SDK-side decision B.

The convergence pipeline (untrusted LLM candidate → deterministic disposition → signed
canonical envelope → ledger ingest) is SUBSTRATE property. QinaoRuntime's only future
role is CONSUMER of already-converged, already-signed envelopes (as data — consistent
with the integration charter's boundary rule 1). No SDK-side convergence machinery; no
early firing of decision B.

## Ruling ② — Ledger doctrine holds; mirror lane is proposal-only

> Ledger deterministic, never routes 4B/LLM as a decision path. Mirror lane 只能产出
> proposal / warrant / annotation,不能直接 mutate Ledger。LLM 输出必须作为 untrusted
> candidate 进入 deterministic accept/reject/reduce 路径。

- The Ledger's decision path stays 100% deterministic. No LLM in the loop, ever.
- The mirror lane's output universe is CLOSED: `proposal | warrant | annotation`.
  None of these mutate the Ledger directly.
- Every LLM output enters as an UNTRUSTED CANDIDATE and is disposed by a deterministic
  accept / reject / reduce gate (reduce = strip to the safe annotation subset).

## Ruling ③ — Signing point: after canonicalization, before ingest

> 在 Warrant/ProposalEnvelope canonicalized 之后、Ledger ingest 之前。Ledger 只接受
> signed canonical proposal envelope;unsigned/schema-invalid 直接 reject。签名 payload
> 必须包含 evidence/source ids、model id、prompt hash、policy hash、timestamp/provenance.

Pipeline order is FIXED: validate → canonicalize → sign → ingest-gate-verify → append.
The Ledger's ingest gate rejects (typed, no partial write) anything unsigned or
schema-invalid. The signed payload MUST bind, at minimum:
`evidenceIDs` + `modelID` + `promptHash` + `policyHash` + `producedAt`/provenance —
so a landed envelope is fully attributable: which model, from which prompt, under which
policy, citing which evidence, when.

## Build plan (each stage: TDD teeth + reversal + individual commit + regression)

- **M1** Envelope: canonical value type in BASHostKit carrying the closed kind set
  (proposal/warrant/annotation) + the ruling-③ provenance fields; injective canonical
  encoding; HMAC signature over the canonical bytes.
- **M2** Deterministic disposition gate: untrusted candidate in → accept (canonicalize +
  sign) / reject (typed reason) / reduce (annotation-only subset) — a pure, clock-injected
  decision; no LLM, no I/O.
- **M3** Ledger ingest gate: verify-then-append; unsigned/schema-invalid/wrong-key →
  typed reject, zero partial writes; landed entries are digest-bearing journal entries
  (substrate stores digest, host owns content — increment-1 doctrine unchanged).
- **M4 (deferred by ruling ①)** QinaoRuntime-side consumption: NOT built now; envelopes
  reach the SDK only as data when a real host adopts.
