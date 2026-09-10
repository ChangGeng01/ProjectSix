# Qinao Manifesto v7 — Multi-Instance Audit Convergence

> Two hosts, one truth.
> Symmetric merge or it didn't happen.

**Status**: target doctrine spec, additive on top of v1–v6. Authored
2026-05-02 (M346) after M342 supplied the measurement-plane leg of
the v5 triple for the multi-instance distribution candidate. v7 makes
a substantive runtime promise about cross-host audit ledger merging.

**Source of authority**: implementation-grounded — every claim is
bound to a typed primitive, a measurement, and a regression gate
(per v5 doctrine triple).

---

## §1 The promise

The substrate carries a typed cross-device merger
(`BASSovereignFragmentMerger`) plus a typed cross-device clock
(`BASSovereignCrossDeviceClock`) plus a typed cross-device ledger
frame (`BASSovereignCrossDeviceLedgerFrame.originDeviceID`).
Together they let two host instances — each with its own hostID,
constitution, and audit ledger — produce a converged consensus
audit timeline.

**v7 promises**: the consensus timeline is *deterministic,
symmetric, and lossless*.

- **Deterministic**: same input frames → same output, byte-equal,
  across processes.
- **Symmetric**: `merge(A, B) == merge(B, A)`. Order of hosts
  presented to the merger does not change the outcome.
- **Lossless**: every distinct frame from either side appears
  exactly once in the consensus. No duplicates introduced; no
  contributions silently dropped.

Combined: v7 gives multi-instance hosts a strong consensus contract
without any cross-host coordination protocol — the merger is a pure
function over the two ledger fragments.

---

## §2 The triple

| Leg | Primitive |
|---|---|
| Typed pin | M329 `BASSovereignFragmentMerger` + `BASSovereignCrossDeviceClock` (vector clock with element-wise max) + `BASSovereignCrossDeviceLedgerFrame` (`originDeviceID` carries hostID semantically per chapter 七十八.4) |
| Measurement | M335 `MultiHostDemo` proves symmetric merge + commutative clock + isolated constitutions + no duplicate frames in one demo run; M306 multi-session demo proves cross-process audit chain continuity for the single-host case that v7 generalises |
| Regression gate | M342 `BASMultiHostConvergenceMetric` — `allInvariantsHold` + `failingInvariants` consumer surface; `measure(framesA:framesB:clockA:clockB:clock:)` factory drives forward + reverse merge to verify symmetry |

A future PR that:
- Changes the `mergeOrdered` algorithm to one that drops a frame
  under any condition: M342 measurement returns `framesInConsensus
  != totalFramesInput - frameOverlapCount` → `failingInvariants`
  fires.
- Introduces non-determinism (e.g., reads `Date()` for tiebreak
  instead of `originDeviceID < lex < auditEntryRef`): the
  `mergeIsSymmetric` field flips false in measurement → fires.
- Forgets to dedup frames present in both inputs: `duplicateFramesIn
  Consensus > 0` → fires.

There is no silent path for the merger contract to drift.

---

## §3 What v7 enforces

1. **Single commit mouth per host preserved.** v7 is a property of
   the *audit ledger merge operation*, not of host-side decision
   making. Each host still owns its own verdict / permit gate.
   Merging audit fragments does NOT promote cross-host commits.
2. **Element-wise max clock merge is commutative.**
   `BASSovereignCrossDeviceClock.merged(with:)` returns the same
   clock regardless of which side is on the left. M335's
   `testClockMergeCommutativeAcrossHostIDs` pins this.
3. **HostID namespacing isolates constitutions.** Two hosts with
   distinct `hostID` values have logically isolated constitutions
   even when their audit fragments are merged. M335's
   `testDistinctHostIDsGiveDistinctClockKeys` pins this.
4. **Concurrent frames resolve deterministically.** When two
   frames have concurrent vector clocks (neither happens-before
   the other), `BASSovereignFragmentMerger.orderBefore` falls back
   to `originDeviceID` ASC, then `auditEntryRef` ASC. Both are
   strings; both are deterministic across processes.
5. **Empty fragments preserve the other side verbatim.** M335's
   `testEmptyHostFragmentsPreserveOtherHostVerbatim` pins this.
6. **Measurement plane reflects the merger contract.** M342's
   `testMetricMatchesFragmentMergerContract` pins that the metric's
   `framesInConsensus` and `duplicateFramesInConsensus` fields
   reflect exactly the production merger output.

---

## §4 What v7 does NOT promise

- **Not a transport.** v7 promises the *merge algorithm* is sound;
  it does not promise that frames have been transferred between
  hosts. Transport is the host's responsibility (M335 demo uses
  in-process simulation; real networks / iCloud / direct
  connections are outside the substrate).
- **Not byzantine fault tolerance.** v7 assumes each host is
  honest about its own clock and frames. A malicious host that
  forges frames or rewinds its clock will produce a bad consensus.
  v7's invariants are not adversarial-safe; they are
  cooperative-safe.
- **Not real-time consistency.** v7 says nothing about how
  recently each host's fragments were merged. A host that hasn't
  exchanged with peers in days still has a locally consistent
  view; the merged consensus is "as of the last exchange".
- **Not cross-host weight sharing.** v7 promises audit-ledger
  consensus, not weight-sharing. Each host's L2/L4 weights remain
  isolated unless explicitly trained from a shared corpus (which
  is v1 #3 + v8 candidate territory, not v7).
- **Not unlimited convergence rounds.** v7 promises *eventual*
  consensus through merge. The number of rounds needed (typically
  one for the canonical case) is not pinned by v7 — that's a
  measurement-plane number that future ceilings could pin.
- **Not multi-host verdict promotion.** A verdict admitted on host
  A is not automatically admitted on host B even after merge. The
  merged ledger reflects what each host decided; cross-host
  verdict transfer requires explicit host-level promotion (which
  is L14 sovereign control plane territory, not v7).

---

## §5 How v7 composes with prior axes

| Axis | Composition |
|---|---|
| v1 #2 (network never rules) | v7 reinforces — merging two hosts' audit ledgers does not bypass either host's three-signature gate. The merged consensus is a record of decisions, not a decision-making layer. |
| v2 (14 living net) | v7 lives at L14 (sovereign black ring) — it is a property of the audit ledger fragment merger. Other layers' invariants are unchanged. |
| v3 (typed motherboard) | v7 IS a typed motherboard claim — `CrossDeviceClock` / `LedgerFrame` / `FragmentMerger` are typed primitives with M120-style schema parity. |
| v4 (agent fabric) | v7 is orthogonal — the 9-seat fabric runs within a single host. v7 concerns merging two hosts' ledgers, each of which may have its own 9-seat fabric. |
| v5 (performance is doctrine) | v7 satisfies the v5 triple in full. M342 is the measurement plane primitive; M335 is the demonstration; M329 is the typed pin. |
| v6 (self-evolution without drift) | v7 is orthogonal — v6 concerns L13 lifecycle structural integrity within a single host; v7 concerns L14 audit ledger merging across hosts. |

v7 does not weaken any v1–v6 invariant. It strengthens v1 #2 by
ensuring multi-host audit consensus does not become a back door
for cross-host verdict transfer.

---

## §6 What can falsify v7

The doctrine fails if any of the following becomes true:

1. The live `BASSovereignFragmentMerger.mergeOrdered(A, B)` does
   not equal `mergeOrdered(B, A)` for some inputs. M335's
   `testMultiHostMergeIsSymmetric` fires; M342's
   `testDisjointHostsProduceCleanConsensus` fires
   (`mergeIsSymmetric == false`).
2. The merged consensus contains duplicate frames. M342's
   `testDisjointHostsProduceCleanConsensus` fires
   (`duplicateFramesInConsensus > 0`).
3. The merged consensus drops a contributed frame. M342's
   metric reports `framesInConsensus < totalFramesInput - frameOverlapCount`
   → `failingInvariants` non-empty.
4. The cross-device clock merge becomes non-commutative. M335's
   `testClockMergeCommutativeAcrossHostIDs` fires.
5. Distinct hostIDs do NOT produce distinct clock counter keys
   (e.g., a hash collision in the underlying dict implementation
   gets exploited). M335's `testDistinctHostIDsGiveDistinctClockKeys`
   fires.

Each is a CI-time falsification — v7 cannot survive a green test
suite that contradicts it.

---

## §7 Authoring boundary

This is v7, not v8 or v∞. Future axes that want to make claims
*about* multi-host distribution must:

- Either inherit from v7 (adding latency claims like "merge must
  complete in N ms for K-frame ledgers") which requires its own
  measurement ceiling + regression gate.
- Or operate at a transport layer (which requires real network
  primitives, currently EB-3 territory in
  `QINAO_EXTERNAL_BOTTLENECKS_BACKLOG.md`).

The "two-host" cardinality is illustrative, not pinned. The merger
algorithm is `O((|A|+|B|) log (|A|+|B|))` and works for any
finite number of hosts via repeated pairwise merge — but v7 only
*promises* the two-host case directly. Multi-way merge is left to
host orchestration code.

---

*Authored 2026-05-02 as M346 — direction "剩下的 一次性 解决" of the
内部加强完善 batch closure. v7 covers cross-host audit ledger
convergence; it composes orthogonally with v6 (intra-host evolution
lifecycle structural integrity) without overlap.*
