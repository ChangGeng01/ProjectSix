# Qinao Global Invariant Firewall and Recoverable Runtime Design

Date: 2026-08-10
Status: approved design direction; blocked design candidate pending source admission
Execution authority: none

## Authority and scope

This document records the approved whole-system design that prevents a local
optimization from weakening Qinao's global correctness. It is not a second
implementation plan, Owner Ledger, schema registry, runtime authority, Wave,
Store, Manager, or cutover receipt.

The only executable authority for Tasks 0–2 remains
`docs/superpowers/plans/2026-07-29-qinao-dual-space-automation-controlled-convergence.md`.
The fixed controlled-document set contains exactly seven documents in total:
the convergence master, which owns W0–W6 order and completion, plus six domain
documents. This file is not an eighth controlled document.

The current annex admits the 2026-07-29 primary design and one 2026-08-02
supplemental design edge and forbids another supplemental edge. Therefore this
file is not yet a legal Task-2 input even though its design direction has user
approval. Before Task 2 may read it, a separate user-approved Tasks-0–2
source-admission amendment must be fixed by an external approval record that
does not use this file as its own authority. That record binds the amendment's
commit, tree, tool/controller identity, operation identity, and protected
policy predecessor. The amendment must then:

- name this exact repository path;
- pin the containing commit and tree, Git blob identity, byte length, and
  content digest from outside this file;
- version the existing design-edge protocol and outer transition registry;
- add the file to the Task-2 candidate and risk inventories; and
- prove that the amendment changes no W1–W6 production behavior by itself.

The amendment uses the incumbent design-edge owner, signer set, protected ref,
stable-open rules, and ref-CAS; it creates no owner, M row, create permission,
or controlled document. It freezes a `QinaoDesignEdgeAdmissionBundleV2`
successor whose ordered entries are the already-admitted 2026-08-02 tuple and
this 2026-08-10 tuple. The primary
`QinaoDualSpaceSourceSelectionV1.approvedDesign` remains the 2026-07-29 design.

The outer transition registry remains exactly nineteen ordered positions.
Historical V1 chains and receipts replay byte-identically under the V1 schema;
they are never rewritten. A new V2 chain versions logical transition 02 itself
from the single supplemental-design edge into the
`QinaoDesignEdgeAdmissionBundleV2` successor. That V2 transition consumes the
exact V1 transition-02 receipt, reopens the already-admitted 2026-08-02 entry,
and admits the ordered 2026-08-02 plus 2026-08-10 bundle before any Task-2
candidate read or W0 transition. Original transitions 03–19 retain their
logical names, relative order, and behavior, but their V2 receipts and
operation keys bind the V2 transition-02 candidate tree as the immediate
design-source predecessor and remain schema-distinct from historical V1
receipts. There is no
transition 20 and no W0–W6 action may precede the V2 design receipt. The V2
base tree already contains the valid 2026-08-02 edge; its candidate tree
differs only by the exact 2026-08-10 blob. The closed presence matrix is:

- valid 08-02 present and 08-10 absent: admit exactly the pinned 08-10 blob;
- both exact entries present with a matching V2 receipt: byte-identical
  `alreadyPresent` replay;
- both exact entries present but the V2 receipt is missing, stale, or foreign:
  quarantine and fail as unadmitted foreign state; ambient adoption and
  `alreadyPresent` are forbidden;
- 08-02 absent or mismatched: fail because the predecessor is invalid; and
- 08-10 present with any path/blob/length/digest mismatch: fail as foreign
  state.

One stable operation identity binds both ordered tuples, the direct and
immediate V1 transition-02 predecessor receipt, V2 base/candidate trees,
logical registry ordinal 02,
signer scope, and protected ref. Retry or lost reply first looks up that
identity; changed bytes never create a second transition. V1 and V2 use
separate receipt/schema identities: historical V1 replay remains supported,
but no V1 consumer may interpret the V2 bundle and no V2 field is backfilled
into a V1 receipt.

Until that amendment is admitted, this file is blocked evidence and no
candidate may ambient-read it. After admission, Task 2 must transplant every
production-adopted requirement into the fixed seven controlled documents.
Research-only, rejected, non-goal, and control-turn rows receive an explicit
disposition but do not acquire production selectors. If the controlled
documents and this design disagree, execution fails closed; this file never
wins by prose precedence.

This design covers five inseparable areas:

1. authority and persistence;
2. conversation, plan, inquiry, and recovery;
3. identity, persona, HumanFit, and App-Agent isolation;
4. model, Apple, toolchain, performance, and physical degradation;
5. learning, biomimetic inspiration, and long-term portability.

## Problem statement

The existing plan contains strong local contracts, but several of them cannot
all be true at once:

- the retention request is interaction-specific while checkpoints and inquiry
  messages require generic Artifact admission;
- an inquiry body is called immediately `userDurable` while its pre-head crash
  orphan is also called collectable;
- the main conversation head and Mission graph root can advance separately;
- an inquiry request freezes both a branch predecessor and a changing global
  EventLog head;
- a continuity manifest can point to a checkpoint that points back to the same
  manifest;
- adding a Sub-agent milestone head would create a third progress authority;
- the monolithic Swift test target depends on model adapters while the
  model-erased gate forbids those same dependencies;
- protected commands prohibit PATH-discovered tools while many candidate
  commands still invoke bare `python3` or `swift`;
- legacy persona and psychological-state paths can bypass the proposed
  structured identity and learning boundaries.
- the Artifact Mesh still exposes mutable CAS heads while K3 is also planned as
  the sole mutable currentness authority;
- current publication and external-effect paths can cross possible-start while
  their processed/spent truth exists only in process memory or a nonterminal
  audit row;
- putting a body before K3 reserves its retention identity creates an
  unenumerable crash orphan with no trusted 72-hour horizon;
- reopening every transitive ancestor inside every writer transaction makes
  commit cost grow with total history and eventually turns safety validation
  into deterministic liveness failure; and
- an Artifact or owner actor awaited from inside `BEGIN IMMEDIATE` can re-enter
  the K3 actor or invert lock order, corrupting or deadlocking the sole writer.
- the shipping EventLog exposes caller-cutoff pruning, including a 24-hour
  policy, without trusted retention or durable-head reachability proof;
- shipping deletion can report `completed` from process-memory receipts and
  static cache-tier names while KV, WAL, derived, in-flight, or external copies
  remain able to resurrect data;
- shipping UserState, training export, local KV persistence, and remote Provider
  adapters expose plaintext/arbitrary-path or arbitrary-destination mechanisms
  without one current K3/K4/external-copy lineage; and
- caller-constructible Agent specs, persona warrants, visibility, thresholds,
  write domains, and commit flags can compose into self-minted authority that a
  cold restart then preserves.

Passing local authoring tests is therefore necessary but insufficient. A Wave
is admissible only when its change also satisfies every global invariant and
every cross-domain mutation gate in this design.

## Goals

- Recover every legally persistable, Qinao-owned committed state from durable
  evidence rather than continuous process lifetime.
- Require a durable plan before executable allocation.
- Preserve committed ordinary conversation, plan, and inquiry history until
  explicit authorized deletion.
- Preserve every lawfully persistable uncommitted recovery object for at least
  72 hours, absent a higher-priority deletion, consent, secret, or
  privacy/security fence, without turning failed precommit objects into
  permanent garbage.
- Keep one Artifact store, one K3/EventLog writer, one context compiler, one
  effect authority, one publication authority, and one governed Artifact
  schema registry.
- Keep Main, Sub-agent, model, PCC, Apple, and experimental mechanisms unable
  to mint authority from confidence, availability, or performance.
- Keep the system useful when every language model, every learned mechanism,
  PCC, or the Apple ecosystem is absent.
- Make archival recovery portable across storage engines, implementation
  languages, toolchains, cryptographic generations, and model portfolios.

## Non-goals and honest limits

Qinao does not claim to persist or recreate:

- unsent hidden chain-of-thought;
- a dead Swift stack, PTY, process handle, or OS-private memory;
- a secret that policy forbids persisting;
- remote API or PCC hidden state;
- an external effect that has already crossed a possible-start boundary;
- the exact internal neural trajectory of a prior model implementation.

Those cases resolve to deterministic replay, semantic reconstruction,
same-operation query/reconciliation, or typed unavailable. No component may
represent one recovery quality as another.

## Global Invariant Firewall

Every Task-2 adoption row, Wave candidate, migration, performance variant, and
cutover must prove all of the following.

### 1. Authority conservation

- Immutable bodies use the sole Artifact Mesh.
- Mutable heads, row versions, epochs, idempotency, and CAS use the sole K3
  writer backed by `BASSQLiteEventLogStorage`.
- After the controlled head migration, the Artifact Mesh has no public
  production mutable-head API. Its legacy head table is migration/read-only
  evidence and never competes with K3 currentness.
- K4 grants or revokes capabilities but never stores domain state.
- The sole context compiler remains `BASContextCompiler`.
- Provider, Apple, web, MorphoHDL, learning, and presentation mechanisms emit
  proposals, observations, or effects through incumbent boundaries. They do
  not become authorities.

No repair may add a second conversation Store, plan Store, checkpoint Store,
share registry, persona Store, HumanFit Store, milestone queue, progress head,
replay Store, or policy Manager.

No K3 SQL transaction awaits another actor, opens an Artifact transaction,
performs filesystem or network I/O, or calls an external effect. Immutable
Artifact validation occurs before `BEGIN IMMEDIATE`; the transaction then
synchronously revalidates the complete K3 revision/head/epoch vector and
commits or fails. Receipt materialization occurs only after COMMIT. The global
lock order is therefore Artifact preflight → K3 synchronous transaction →
postcommit Artifact materialization; the reverse order is forbidden.

### 2. Wave and dependency direction

- W0 inventories and classifies incumbent paths.
- W1 declares low-level public contracts and strict codecs.
- W2 owns persistence, K3 transactions, migration, retention, and erasure.
- W3 owns semantic projection, cleaning, context compilation, and candidate
  formation.
- W4 owns execution-plan election, local model adapters, and K1 composition.
- W5 owns Provider egress, bounded web acquisition, publication, and Zone-C
  external effects.
- W6 owns runtime composition, Apple surfaces, replay, certification, and
  production cutover.

An earlier Wave may name later work in non-executable traceability prose and
may use a low-level type that W1 or an admitted predecessor has already
declared. It may not compile against an undeclared later-Wave symbol, consume a
later-Wave receipt, pretend future evidence already exists, or introduce a
reverse package import. RuntimeCore cannot import Memory, Organ,
Orchestration, HostKit, or adapters. HostKit does not import model adapters.
Adapter/composition packages depend inward on the model-neutral core; the core
never depends outward on an adapter package.

### 3. Governed-payload discipline

An independently put and reopened top-level payload has exactly one
`BASGovernedArtifactPayloadCodec`, one row in the sole
`BASEBrainSchemaGovernanceRegistry`, one owner factory, one current fixture,
one future-rejection fixture, and, only when required, one historical-put row.
A contained, self-ID-free, or transient value has none of those independent
entries.

Adding a schema row never changes the Owner Ledger or architecture
cardinalities. The fixed `29 logical owners / 14 M-allowlist entries / 14
create permissions / 7 controlled documents` Ledger cardinalities and
`14 LayerCores / 10 supersteps / 4 kernels / 4 rings / 7 planes` remain
unchanged.

### 4. Acyclic Artifact lineage

- A body, request, envelope, manifest, receipt, checkpoint, and Self successor
  never predict their own Artifact ID.
- Receipt bytes never contain their own materialized Artifact ID.
- A receipt may bind an earlier body or request. An envelope may reference an
  earlier receipt. The receipt never references the later envelope.
- A continuity manifest references only committed strict ancestors.
- A checkpoint may reference a manifest. That manifest cannot reference the
  enclosing checkpoint or any equal-or-greater generation checkpoint.

### 5. Retention is orthogonal to authority

`userDurable` controls time-based retention only. It does not grant learning,
sharing, exporting, caching, publication, or execution. Likewise,
`eligibleLearning72Hours` does not itself authorize training or cutover.

Deletion, consent withdrawal, secret detection, privacy/security
reclassification, and revocation are higher-priority fences. They advance the
relevant epoch, synchronously block reads and capabilities, destroy or isolate
the erasure key, propagate taint, and then clean content asynchronously while
retaining only permitted content-free tombstones and audit proofs.

Storage ports expose no caller-selected time-cutoff prune. A policy enum,
caller-provided `nowMs`, disk-pressure signal, `last24Hours`, or
`pruneEventsBefore(Int64.max)` cannot delete EventLog/Artifact truth. Only the
K3 retention owner may select physical cleanup from trusted admission rows,
minimum/maximum horizons, dependency-closure reachability, deletion epochs, and
content-free tombstones. `userDurable` is never TTL-pruned; a normal
`recovery72Hours` expiry is never earlier than its trusted minimum. Clock
rollback, overflow, missing row, or uncertain reachability fails closed.

### 6. Durable state precedes visible or external action

A user-visible reply, Provider handoff, publication, or external mutation does
not occur until its stable operation identity and durable intent are committed.
After possible-start, recovery is query/reconcile-only under the same identity.
No timeout, crash, or lost reply creates permission to resend.

### 7. Identity and learning isolation

- A Session selects exactly one App Agent and one logical Main.
- Main, Sub-agent, Provider, PCC, and inquiry capsules remain purpose-limited.
- The current Attempt may emit observations but cannot authorize its own
  App-Agent successor.
- A successor becomes visible only to a fresh Attempt after independent
  evidence, the seven cleaning gates, L13/K3, L14, and K4.
- Cross-App-Agent reads grant no write, cache reuse, learning, export,
  resharing, or cutover right.

### 8. Truth and acceleration separation

Committed message bodies, accepted visible output, structured solution
Artifacts, Mission graph roots, and owner receipts are recovery truth.
Indexes, embeddings, reranker caches, summaries, projections, and local KV are
derived or accelerating state and must be rebuildable.

### 9. Physical degradation is real

A profile is not model-erased merely because runtime selection avoids a
Provider. Its selected source, package, target, object, link, resource,
registration, dynamic-loader, network, and test closure must exclude every
forbidden dependency. A nonempty test must actually run inside that closure.

### 10. Performance cannot buy correctness

A faster profile must preserve byte-equal sealed K3/K4 roots, retention
horizons, privacy/egress decisions, causal/replay manifests, recovery receipt
coverage, output-quality floors, grounding, and safety checks. A change to any
of those fields invalidates the performance claim rather than improving it.

### 11. Research cannot become authority

Free-energy, default-mode, neuromodulation, grokking, MorphoHDL, model
confidence, and framework availability are observations or research evidence.
They cannot select truth, bypass risk, allocate a capability, mutate state,
publish, promote a policy, or alter the running Attempt.

### 12. One canonical test ledger

The exact selector set, every `--require-test`, every suite gate, per-Wave
partition, risk inventory, total, and hash derive from one canonical ordered
set. A test name added to only one representation fails authoring immediately.

### 13. Bounded liveness is correctness

Every foreground K3 operation has a fixed maximum delta item count, canonical
byte budget, SQL statement count, and transaction-duration budget independent
of the total conversation age. Retry never repeats an already proven
history-wide scan. History-wide verification is paginated, resumable audit or
certification work outside the writer transaction; exceeding its budget cannot
permanently block new lawful conversation, deletion, recovery, or effect
reconciliation.

An unbounded recursive reopen, unbounded reverse-index walk, or `await` while a
writer lock is held is a correctness failure even when it validates more state.
Fail-closed means typed backpressure with a recoverable continuation, not a
permanent retry loop over the same over-budget work.

## Canonical persistence protocol

All committed conversation, plan, inquiry, checkpoint, and resumable-work
lineages use one recursive, acyclic protocol. Three object classes are never
conflated:

1. A **pre-receipt body** is self-ID-free encrypted content or a structural
   governed payload that refers only to already existing ancestors.
2. A **post-receipt binding** is a contained request or binding that refers to
   the earlier body and its retention receipt. It is never the same type or
   bytes as that body.
3. A **K3 head fact** is the sole mutable adoption/currentness decision. It is
   not an Artifact body and is written only by the sole K3 writer.

All following uses of “digest” obey one closed taxonomy. A raw digest is legal
only for public build inputs, ciphertext/record fixity, authenticated receipt
bytes, or another preimage that contains no confidential plaintext or exact
plaintext length. Prompt, message, persona, plan, Solution, compiled context,
share body, Provider/export request, UserState, and every derivative of those
classes use a strict `BASArtifactContentCommitment` tagged value after leaving
custody: `.publicDigest` is permitted only for the closed public-inline class;
`.confidentialKeyed(BASConfidentialContentCommitment)` binds algorithm, domain,
key epoch, schema, scope/subject, erasure domain, canonical plaintext digest,
and exact length under that custody owner's domain-separated secret. K3,
EventLog, semantic operation keys, receipts, manifests, and owner journals store
only the typed opaque commitment, Artifact ID, or sealed-record digest. They
never store the raw confidential digest, exact plaintext length, or commitment
key. Different custody owners cannot share one globally correlatable
commitment key.

A stable semantic operation key is independently scoped by owner, Workspace/
Session/incarnation, operation kind, and a caller-independent request/
idempotency identity. It is never just an Artifact ID or content commitment.
Byte-equal content may therefore have several lawful admissions or uses without
collapsing their authority, retention, recipient, or deletion obligations.

The protocol is:

1. Canonically construct the self-ID-free body bytes and stable semantic
   operation key in memory. Before Artifact identity preparation, the same K3
   operation row enters finite `identityPreparing`, binding the Artifact-store
   lineage/incarnation, selected public commitment-key epoch descriptor,
   erasure scope, purpose, epoch vector, deadline, and one authenticated
   preparation generation/nonce. The commitment-key epoch is selected and pinned by the
   same K3 writer that serializes key-retirement permission; the Artifact
   custodian cannot retire it until K3 proves zero live preparation,
   reservation, or claim rows. K3 returns a package-private finite preparation
   token whose fixed unsigned body binds operation-row ID/revision, store
   identity/incarnation, preparation generation, selected commitment-key epoch,
   erasure scope, purpose, deadline, nonce, and storage-auth algorithm/key epoch/
   verifier and contains
   no content bytes. The same storage-auth profile MACs/signs that body; K3
   persists and byte-equal reopens the authenticated token, and only the exact
   Artifact custodian can verify/use it. Callers cannot initialize, default,
   type-erase, or forge a preparation token.
2. The sole Artifact actor performs transaction-free, read-only
   `prepareIdentity(identityCore, preparationToken)` using its private resolver
   at that exact pinned epoch. It returns a transient
   `BASPreparedArtifactIdentity` containing expected Artifact ID, typed content
   commitment, identity-core commitment, store identity/incarnation, and
   commitment-key epoch. No key material leaves the store. K3 atomically
   attaches those commitments to the same semantic row and transitions it to a
   stable `retentionAdmissionID` reservation. A crash before attachment leaves
   a finite preparation row; retry must use the same epoch/token or cancel it.
   A changed identity or bytes under the semantic key is corruption.

   The preparation subject is a closed
   `ordinaryPrecommitBody | historicalReceiptObligation` union. Preparation
   storage-auth verifier material remains usable until that exact generation is
   attached, explicitly cancelled where cancellation is legal, or expired and
   its tombstone horizon closes; claim-generation retention is not a substitute.
   For an `ordinaryPrecommitBody` whose typed content commitment has not
   attached, expiry atomically tombstones generation `g` and terminally cancels
   that semantic operation. It never renews a token under the same operation
   before a content commitment exists. A caller that still needs the inert put
   starts a new semantic operation/reservation, which may lawfully bind the same
   byte-equal Artifact through its own claim binding.

   A `historicalReceiptObligation` exists only after the immutable history
   decision has committed canonical receipt bytes, typed commitment,
   materialization key, and pinned commitment-key epoch. That obligation cannot
   be cancelled merely because a preparation window or process ended. On expiry
   K3 atomically tombstones preparation generation `g` and issues exactly one
   generation `g + 1` under the same history decision, receipt bytes, typed
   commitment, materialization key, and pinned identity epoch. The storage-auth
   generation may advance, but receipt semantics and identity inputs may not.
   Lost token return, reboot, and auth-key rotation therefore remain byte-equal
   repair, not a new receipt or semantic operation. A higher-priority lawful
   deletion may substitute only the already defined content-free tombstone
   disposition; it cannot silently abandon a committed head behind a permanent
   materialization gate. In both cases the old token becomes unusable while its
   tombstone/verifier remain; two live generations or a late attach cannot pass
   the row CAS. A changed body is a new operation or corruption, never silent
   token renewal under another identity epoch.
3. Before Artifact write, that reservation binds the expected Artifact ID,
   typed content/identity commitments, purpose, epochs, erasure domain,
   canonical content-free precommit blueprint, a short put deadline, trusted
   start, and a provisional horizon long enough to guarantee at least 72 hours
   after any accepted put. Exact retry reopens it; confidential body bytes or
   raw body digests never enter K3.
4. Immediately before Artifact write, K3 atomically transitions that row from
   `reserved` to `putClaimed`, increments a claim generation, fixes a durable K1
   trusted-time coordinate, clock-domain/boot incarnation, `claimDeadline`, and
   provisional minimum at `claimDeadline + 72h`, and returns one opaque,
   authenticated `BASReservedArtifactPutAuthorization`. It binds the reservation
   and admission IDs, claim generation and row revision, expected Artifact ID,
   typed identity-core commitment, store incarnation, commitment-key epoch, deadline,
   clock domain, one-time nonce, storage-authorization algorithm/key epoch,
   and verifier identity. These fields form a fixed canonical unsigned body
   that contains neither its own digest nor an authenticator. K3 signs or MACs
   `domainSeparator || canonicalUnsignedBody` with a storage-authorization key
   unavailable to callers, stores the complete authenticated authorization
   bytes in the claim row, and separately stores a `completedTicketDigest` over
   those final bytes. That completed digest is referenced only by the Artifact
   record/commit proof and is never written back into the ticket. Lost
   claim reply reopens that row and returns those byte-equal bytes rather than
   minting a new ticket. A rotated key becomes verify-only for existing claim
   generations: its verifier material cannot retire until every corresponding
   claim generation, tombstone, and provisional horizon is closed. New claim
   generations use the admitted successor key and never silently rewrite an old
   authorization. Cleanup never deletes the expected-ID mapping, canonical
   ticket bytes, verifier identity, or claim tombstone before that closure.
5. A package-private `reservedPut` seam accepts that authorization plus the
   prepared identity and permits exactly one absent-or-byte-equal write in the
   same Artifact store. Before its own transaction it verifies the K3
   authentication and store/claim identity through a pinned read-only verifier;
   callers cannot construct, default, type-erase, or substitute the
   authorization. The store recomputes the ID, core, store identity, and key
   epoch and must commit before the authorization's trusted deadline; a queued
   write reaching COMMIT at/after the deadline rolls back. The immutable
   identity/content record binds only stable Artifact identity and content
   commitments—never one reservation, claim, ticket, or proof.

   In that same Artifact SQLite transaction, the owner appends one bounded
   `artifact_put_claim_binding` implementation row keyed by
   `(artifactID, authorizationSubjectKind, subjectID, claimGeneration)`. It
   stores the admission/history subject, completed-ticket digest, typed content
   commitment, store lineage/incarnation, K1 commit coordinate, proof
   algorithm/key epoch/verifier, and the complete canonical authenticated commit
   proof bytes. ID absent inserts identity/content plus the exact binding; ID
   present first byte-verifies identity/content and then inserts only the new
   binding. An equal binding tuple reopens its byte-equal proof; the same tuple
   with changed bytes is corruption; another reservation for the same Artifact
   is legal and receives an independent binding/proof. This transactionally
   persisted proof is the recovery source if the return dies after COMMIT.
   Proof signed/unsigned bodies exclude their own digest/tag. Verify-only public
   material remains until all bindings/horizons close; a durable anchored
   closure attestation is required before any MAC verification secret retires.
6. Outside any SQL transaction, the retention owner reopens the immutable body
   plus the exact claim-binding/proof and creates a validated preflight
   snapshot. K3 then synchronously rechecks the `putClaimed` row, proof digest/
   verifier and all relevant K3 epochs/row versions, binds the body, and
   commits the final retention row. Its minimum is the maximum of the
   provisional horizon and trusted bind time plus 72 hours.
7. That same K3 transaction freezes one immutable
   `BASK3HistoryDecisionRevision` inside the existing operation-history row. Its
   stable decision ID/revision/root binds canonical admission-receipt bytes and
   typed commitment, deterministic materialization semantic key, pinned
   preparation epoch, and the structural-certificate blueprint whose parent is
   the admitted body certificate. A separate mutable
   `materializationRevision/generation` starts in `materializationPreparing`.
   Receipt bytes, receipt identity, and the history decision never bind that
   mutable lifecycle revision and never change after the decision COMMIT. The
   transaction does not predict an Artifact ID. After COMMIT, the Artifact
   owner prepares the identity under a K3 preparation token; a short K3
   transaction attaches the expected ID/commitment to the materialization
   generation and issues the same
   `BASReservedArtifactPutAuthorization` with closed
   `.historicalReceipt(historyOwnerKind, historyRowID, materializationKey,
   claimGeneration)` subject. Its unsigned body, complete authenticated bytes,
   completed-ticket digest, deadline, verifier, and expected commit-proof
   verifier are persisted in that history row. The existing
   `BASArtifactHistoricalPutPort` may only delegate this sealed authorization to
   the same `reservedPut` implementation and returns the same proof type; a kind
   allowlist or row-pinned core/epoch alone is never authorization.

   Artifact COMMIT creates the exact claim-binding/proof row above. Outside all
   transactions K3 reopens the receipt, binding, and proof; a short
   `completeReceiptMaterialization` transaction rechecks the immutable history
   decision plus only the current materialization generation/proof digest,
   installs the receipt structural certificate, advances the materialization
   revision, and clears pending. It cannot revise the history decision or feed
   a later materialization revision back into receipt bytes, ID, typed
   commitment, or decision root. Exact retry reopens the same ticket/proof;
   keys remain verify-only until certificate/horizon closure. The history row
   pins the content-free receipt without a receipt-of-receipt.

   The immutable decision root is computed over a domain-separated canonical
   decision body containing the stable history-row identity and immutable
   decision revision, but excluding the decision-root field itself, every
   mutable row/materialization revision, the future receipt Artifact ID, the
   receipt certificate/commit proof, and every authenticator over those fields.
   Canonical receipt bytes may bind the stable history-row identity and immutable
   decision revision; they never bind the decision root or their own future
   Artifact ID. The decision root may therefore commit the frozen receipt bytes
   without a root-to-receipt-to-root fixed point. A codec that places any
   excluded field back into either preimage fails before COMMIT.
8. Construct the next structural governed payload, such as a conversation
   envelope, Mission graph, or checkpoint ref, using only the earlier body and
   receipt. Because that payload is independently reopened after restart, it
   repeats steps 1–7 under a distinct reservation/admission and never embeds its
   own receipt.
9. Outside the writer transaction, preflight the current logical predecessor,
   the prior dependency-closure commitment, and only the bounded new dependency
   delta into an immutable validated snapshot.
10. Construct the contained post-receipt head/adoption request. K3 begins no
   transaction until preflight is complete; after `BEGIN IMMEDIATE` it performs
   synchronous SQL-only revalidation of the snapshot's complete K3 revision,
   head, retention-decision, deletion/revocation, and epoch vector.
11. K3 atomically applies authorized retention promotions, advances the logical
   head or heads, and extends the incremental durable-dependency closure root.
12. Materialize, reopen, and complete the structural certificates for the
    canonical K3 operation and promotion receipts by the same history-row
    protocol; only then may cross-owner readers or later effects consume the new
    state.

`BASRetentionAdmissionRequest` remains the one request family but becomes
Artifact-capable. It owns the precommit `retentionAdmissionID` and a strict
contained `BASRetentionAdmissionSubject` with closed tags for
`BASInteractionRetentionSubject` and `BASArtifactRetentionSubject`. It does not
reuse the final `BASInteractionExperienceEnvelope`, and the admission ID does
not appear in two competing owners. `neverPersist` and uncommitted `ephemeral`
reject an Artifact admission ID; every Artifact-admitted class requires one.

For resumable pre-head work, the contained precommit blueprint binds the
Workspace, Session/incarnation, App-Agent selection, semantic operation key,
logical predecessor, intended message/graph/adoption role, typed body content
commitment, and canonical content-free envelope/root-request blueprint
commitment. The K3 retention row stores enough non-confidential canonical
blueprint facts to reconstruct intent byte-identically after a crash; body or
request bytes remain only in encrypted custody. Orphan cleanup must first query
the stable operation key and prove that no committed head references the
lineage.

`BASPreparedArtifactIdentity` is transient and non-Codable.
`BASRetentionAdmissionRequest` is versioned in place with a strict contained
phase tag: `identityPreparing`, `reserveExpectedArtifact`,
`claimReservedPut`, and `bindAndAdmitReservedArtifact`. Preparation/
reservation/claim results and reserved-put authorization are contained/
transient K3 values, not independently put payloads, schema-registry rows, K4
domain capabilities, or second Artifact identity/retention authorities. The
authorization is nevertheless mandatory authenticated storage-write authority;
“not K4” never means caller-forgeable.
The commitment key and
resolver remain private to the sole Artifact actor; K3/callers receive only the
prepared identity's commitments. Key rotation cannot retire a pinned preparation
epoch until its reservations bind, expire, or are explicitly cancelled. A
reservation with no claim/body is finite and collectable after its put deadline
and lawful maximum. A claimed put retains its expected-ID mapping/tombstone
through its provisional minimum even if no body arrives. A put with no completed
bind remains discoverable by the reservation's expected Artifact ID and retains
the provisional horizon; it is never an unenumerable Artifact orphan.

For a durable K1 trusted-time coordinate, if `putWindowMs` is the admitted
bounded put window, `putDeadline = reservedAt + putWindowMs`. A successful claim
before that deadline sets `claimDeadline = claimedAt + maxPutDurationMs` and
`provisionalMinimumRetainUntil = claimDeadline + 259_200_000`. Bind sets
`minimumRetainUntil = max(provisionalMinimumRetainUntil,
bindCommittedAt + 259_200_000)`. Addition is overflow-checked and clock rollback
fails closed. The coordinate binds a rollback-protected absolute component plus
its monotonic segment and boot incarnation; a raw uptime value is never compared
across boots. An authorization is unusable outside its clock domain or at/after
`claimDeadline`; the Artifact store uses the same injected K1 verifier only to
enforce K3's deadline, never to choose retention.

After restart, K3 first reopens `expectedArtifactID` and the exact
`artifact_put_claim_binding`. If identity/content exists but this binding does
not, a current authorization may use the closed `bindExistingByteEqual` path:
the Artifact transaction byte-verifies the existing record and appends only the
new binding/proof. If the exact binding exists, K3 reopens its persisted proof
and binds without a second content put. If identity/content is absent and the
old clock domain or deadline is no longer valid, K3 atomically tombstones claim
generation `g` and issues `g + 1` under the same semantic reservation; the old
tombstone remains through its provisional horizon and an old authorization can
never commit. A body is physically collectable only after every retention
admission, claim binding, durable-head pin, custody generation, and deletion
obligation for that Artifact is closed. Exact
reserved/putClaimed/bound/expired state is queried from K3 rather than inferred
from caller time. Reboot-before-put, commit-before-reboot/reply-loss, clock
rollback, domain mismatch, forged authorization, wrong store/row, and changed-
byte replay are all fail-closed cases.

### Incremental durable-dependency closure

Each existing K3 logical-head row owns its own contained, self-ID-free
`BASDurableDependencyClosureCommitment`; there is no global closure head. The
commitment is repeated in that head's existing operation receipt and is not an
Artifact payload, Store, registry row, or new owner. It binds the predecessor
logical head and closure root, an append-only Merkle/MMR frontier and exact
peaks, canonical ordered delta entries, delta root, cumulative root, cumulative
item count, maximum dependency height, and algorithm/domain version. Every
delta entry is one closed `BASDurableDependencyMember` case:

- `.admittedArtifact` binds Artifact ID, typed content commitment, schema/store
  identity, immutable structural-certificate revision ID/root, stable
  retention-admission ID, historical admission-receipt ID/authenticated-byte
  commitment, and required immutable owner receipt; or
- `.k3HistoryReceipt` binds the exact operation-history row ID plus immutable
  `historyDecisionRevision` ID/root,
  receipt kind, materialized receipt Artifact ID/authenticated-byte commitment,
  and canonical materialization-certificate/commit-proof identity. This case
  forbids a retention-admission ID, retention-decision revision, admission
  receipt, or own-receipt field. Its content-free lifetime is pinned by the
  immutable history decision and the same K3 history
  row and any later head that references it.

There is no nil/default third shape. Treating a K3 receipt as an ordinary
admitted Artifact, accepting a foreign history row, or filling an absent field
with a sentinel is corruption, not compatibility.

Retention-decision revisions, custody generations, deletion/privacy/revocation
epochs, and other mutable currentness facts are never leaves of the immutable
dependency accumulator. The transaction-local read set and operation receipt
may record them explicitly as `observedAtAdoption`, but that observation has no
future authority. Every reopen and head CAS resolves the stable admission and
Artifact IDs through the current K3 vector; promotion, authorized
re-encryption, or epoch advance cannot stale an otherwise valid historical
head, while deletion still fails reads in O(1).

At body bind/admission time, the same K3 database appends one immutable
`BASArtifactStructuralClosureCertificateRevision`. It binds only immutable
structure: Artifact ID, typed content commitment, schema/store identity, the
exact structural edge set derived by reopening immutable body bytes, the
resulting transitive structural root, member/depth bounds, and structural
algorithm/domain version. The edge set is a closed
`.artifactParent(parentID, immutableCertificateRevisionID/root) |
.certifiedIndexedSubtree(kind, immutableMembershipRevisionID/root, count,
indexDomain)` union. Ordinary payloads use only exact parent edges. The archive
root may use the certified-subtree case defined below; a caller-supplied root or
mutable staging frontier can never fill it.
It never binds a mutable retention-row revision, decision revision, custody
generation, deletion/privacy/revocation epoch, or currentness fact. Those facts
remain in a separate K3 currentness vector checked at every read and head CAS;
normal retention promotion, re-encryption, or unrelated epoch advance cannot
invalidate or rewrite an old structural certificate.

Every governed schema has a fixed finite structural-edge cardinality. K3 accepts
a certificate only when transaction-external preflight has reopened the body
and every direct parent certificate or sealed indexed-membership revision, and
its SQL transaction synchronously rechecks those exact immutable rows plus the
separate currentness vector. A certificate is therefore inductive proof of the
new Artifact's complete transitive dependency set, not a caller-asserted root
token. It is a K3
implementation row, not an Artifact, head, registry object, retention
authority, or caller-visible token. A structural-algorithm upgrade builds
bounded successor-certificate revisions off the foreground path and activates
one new algorithm root in O(1); it never rewrites all descendants.

Content-free K3 admission/operation/promotion receipts use the
`.k3HistoryReceipt` member shape and the certificate blueprint/completion
transaction stored in their existing operation-history row. They are exempt
from obtaining a receipt for their own retention and can never start a receipt-
of-receipt chain.

The same K3 database also stores indexed per-head accumulator membership rows
and the structural parent/child certificate edges under the existing K3 owner.
They are implementation rows, not a second Store or mutable head. For every
candidate Artifact, transaction-external preflight supplies its current
immutable structural-certificate revision, separate currentness vector, and a
bounded witness showing either that the certificate is already pinned by the
exact predecessor head or that it appears in the ordered delta. Pinning the
certificate root pins its certified members for the head horizon; cleanup may
not expire a member merely because its original `recovery72Hours` row would
otherwise age out. Inside the transaction, K3 synchronously re-queries the
immutable certificate/edge and accumulator row revisions, separately rechecks
retention/custody/deletion/privacy/revocation currentness, and verifies the
witnesses/frontier before appending the delta and committing root, frontier,
membership rows, and logical head together.

A legacy or imported subtree without certificates cannot be smuggled into one
delta or trigger an unbounded foreground walk. The same K3 semantic-operation
row may hold a non-authoritative `pendingClosureBuild` with immutable source
root, canonical frontier/cursor, bounded work budget, and accumulated proof.
Every chunk is topologically ordered and edge-closed: each node's reopened-byte
direct parents are either predecessor-certified or earlier certified nodes in
that build. Crash/retry resumes the same row. Only a complete build whose source
root, predecessor, and epochs still match may be consumed by one final head CAS;
the staging row is then closed and never becomes a progress head. This supplies
finite progress for a valid over-budget subtree without creating a third
currentness authority.

Same-root forged membership, an admitted orphan whose grandparent is omitted,
same-ID/different-content-commitment, missing structural edge, omitted expired parent,
duplicate leaf, invalid peak, stale staged predecessor, or over-height proof
fails. A bare root/count, current retention on only the candidate node, or a
partial frontier is never transitive-closure evidence.

The inductive invariant is therefore evidence-backed: Artifact certificates
prove edge-closed structural ancestry, a committed predecessor accumulator
proves which certified closures are durably pinned, and a successor verifies
old membership plus the bounded new certificate delta. Existing ancestors are
never repromoted or linearly rescanned in the foreground writer path. Deletion,
consent, privacy, and revocation remain O(1) synchronous fences by K3 epoch/key
state; cleanup and descendant invalidation may proceed incrementally after reads
have already failed closed.

`BASValidatedArtifactClosureSnapshot` is a transient, non-Codable value produced
outside the transaction. It binds immutable Artifact records and store identity,
the per-head membership witnesses/frontiers/deltas, and expected K3 read-set
revisions/heads/epochs. Artifact bytes cannot change, and Artifact purge has no
independent authority: it requires a prior K3 fence. Inside `BEGIN IMMEDIATE`,
K3 performs no Artifact reopen and no `await`; it only rechecks its own complete
revision vector, indexed membership rows, and snapshot commitments. Periodic
paginated full-walk audit verifies each accumulator and may create a new
certified checkpoint commitment, but failure or pause of that audit does not
block ordinary bounded commits.

No public K3 mutation request accepts a snapshot or lets a caller construct one.
The same K3 actor method invokes one package-private injected
`BASArtifactPreflightPort` before `BEGIN`; the snapshot initializer and storage
are package-internal and invocation-local. It binds the exact Artifact-store
object identity/incarnation, prepared-identity ticket, reopened record-byte
digests, and K3 read set. Actor reentrancy while awaiting preflight is harmless
because the subsequent transaction rechecks the complete revision vector.
Another store instance, public/type-erased/downcast factory, forged snapshot, or
snapshot reuse across invocations is rejected by API shape and runtime identity.

Transaction `T` may add only bodies and receipts that existed before its
`BEGIN`. `T`'s own operation/promotion receipt bytes, digest, Artifact ID, and
materialization key are never members of `T`'s closure root. They remain
recoverable in the existing K3 operation-history row and may bind the newly
committed root; the root never binds them back. If a later transaction `T+1`
structurally references `T`'s already materialized receipt, `T+1` may add it as
an ordinary delta member. Own-receipt-in-delta, self-parent, and fixed-point
constructions are rejected before commit.

The precommit subject contains no future K3 head, receipt Artifact ID, or later
envelope Artifact ID. The canonical receipt binds the earlier request and
content; it never refers to the later envelope. K3/audit receipts are
content-free proof objects and do not recursively require their own retention
receipt, but durable-head reachability pins their permitted bytes and any
privacy fence reduces them to an allowed content-free tombstone.

### Governed classification delta

This is the new/changed delta, not a replacement for the incumbent closed
registry. Task 2 must preserve and re-list the exact incumbent set. In
particular, the protocol retains:

- `BASRetentionAdmissionReceipt` and `BASRetentionDispositionReceipt` in
  `BASRuntimeCore/BASSemanticStateLakeContracts.swift` under
  `state.snapshot-contracts`, including the step-5 historical put;
- `BASInquiryBranchRef`, `BASInquiryMessageEnvelope`, and their governed
  append/reopen receipts in that same contract path/owner;
- `ContextContinuityManifest` in the same snapshot-contract owner;
- `BASCacheCheckpointIdentity`, `BASContinuationCheckpointRef`, and
  `BASProviderCheckpointReceipt` in
  `BASRuntimeCore/ProviderExecutionCore.swift` under their already frozen
  `cache.scope`, `execution.plan-provider-router`, and
  `provider.package-boundary` owners; and
- every other incumbent row, codec, factory, current/future fixture, and
  historical-put allowlist entry unchanged unless this design explicitly
  versions it.

The new or materially changed independently put values are:

- `BASConversationMessageEnvelope` in
  `BASRuntimeCore/BASSemanticStateLakeContracts.swift` under
  `state.snapshot-contracts`;
- `BASMissionTaskGraph` and `BASSolutionArtifactPayload` in
  `BASRuntimeCore/BASSemanticTurnDAG.swift` under `runtime.semantic-dag`; and
- `BASMissionTaskGraphRootAdvanceReceipt` in that semantic-DAG contract owner
  when historical materialization is required. Promotion continues to use the
  exact existing `BASRetentionDispositionReceipt`; no generic promotion or
  root-receipt family is invented.

Each independent value receives exactly one
`BASGovernedArtifactPayloadCodec`, `BASEBrainSchemaGovernanceRegistry` row,
owner factory, current fixture, future-rejection fixture, and required
historical-put row.

These values are contained or transient and receive no independent row,
Artifact kind, Store, or owner: message role, graph node/status, commit kind,
retention subject/phase/reservation result, reserved-put authorization,
precommit blueprint, `BASDurableDependencyMember`, durable-dependency closure
commitment, validated Artifact preflight snapshot, validated owner-outbox
snapshot, validated K3 possible-start snapshot, prepared Artifact identity,
authorized-read lease, dual-head request, Solution adoption binding,
portable-archive source-universe currentness, source snapshot/lane/page proof/
public-verifier bridge/scan outcome/paired-MMR frontier, transient
`BASValidatedArchivePageSnapshot`, archive-build inactivity lease,
certified-indexed-subtree edge, restore mode/baseline/readiness values, HumanFit
projection, attention projection, `BASModelRosterBinding`, the non-model
`BASLanguageClassifierCapabilityBinding`, stable operation-key parts, and
`BASArtifactV1ToV2MigrationCertificate`. The planned W6 first-wire top-level payload
`BASArchitectureReplayManifest` remains not production-present and belongs to
the existing planned logical owner `runtime.replay-manifest`; its portable
archival envelope and legacy source/sink manifests are contained values. Its
closed `chunk | root` role tag remains one top-level family/registry row rather
than creating a second archive family.

`BASK3HistoryDecisionRevision`, its separate receipt-materialization lifecycle,
`BASArtifactStructuralClosureCertificateRevision`, per-head accumulator
membership/edge rows, `pendingClosureBuild`, archive-cut/page/MMR/certified-
subtree rows, custody-envelope generations,
`pendingHeadCutover`, v1→v2 proof-map staging, and deletion projection/frontier
rows are bounded implementation rows in the already named Artifact/K3 owners.
They are not governed Artifact payloads, logical heads, public caller tokens,
Stores, owners, or registry entries; their source roots and activation epochs
are verified by the protocols above.

The identity-preparation/reserved-put claim/tombstone and canonical
authorization/verifier fields remain contained in the existing K3 retention-
operation row. `artifact_put_claim_binding` and its canonical persisted commit
proof are bounded implementation rows in the existing Artifact SQLite owner;
they are creation/admission evidence, not content identity or currentness. Each
sealed possible-start outbox row and local authenticated journal root remains
an encrypted implementation row in the exact incumbent publication or effect-
saga journal selected by the closed `BASBoundaryOwnerID` mapping. The authenticated K3/EventLog root
and opaque pending/committed anchor generation remain implementation state of
the incumbent K3 owner and physical anchor adapter. None of these row classes
is an ordinary message store, public token, Artifact payload, head, registry
entry, new Store, or second execution decision.

`BASSolutionArtifactPayload` itself is the solution's pre-receipt body. It may
reference already existing evidence ancestors but is not a post-receipt wrapper
around an unnamed solution body. A Mission graph successor
may contain a `BASSolutionAdoptionBinding` that references the already existing
solution Artifact and receipt. The graph body then receives its own admission;
`BASMissionTaskGraphRootAdvanceRequest` references the graph and graph receipt.
Neither the solution nor graph body embeds its own receipt.

## Staged durability and promotion

An object that has not joined a committed conversation or plan cannot begin as
`userDurable` if precommit orphans are meant to be collectable.

The required sequence is:

1. admit the body and its precommit metadata as `recovery72Hours`;
2. construct the envelope or graph request;
3. in the same logical-head K3 transaction, validate the current retention row
   and apply the existing monotonic `promoteUserDurable` disposition;
4. advance the logical head;
5. persist the canonical promotion/root receipt bytes, digest, deterministic
   materialization key, and pending-materialization state in that same K3
   transaction; and
6. byte-identically historical-put and reopen the receipt Artifact, then run
   `completeReceiptMaterialization` to install its contained structural
   certificate and clear pending idempotently.

An authorized `promoteUserDurable` is legal immediately at trusted time
`t = 0`: it lengthens retention and therefore does not violate the finite
minimum. Ordinary expiry or purge still cannot shorten a minimum. The
transaction validates promotion authorization, expected decision revision,
all body and structural receipts, all relevant epochs, and the logical-head
predecessor. If several bodies support one conversation/Mission commit, every
required promotion and both head advances succeed or none do.

Before logical-head promotion, a reserved or bound orphan remains discoverable
and recoverable for at least 72 hours after any accepted put and may be cleaned
after its lawful finite maximum. After the promotion/head commit, committed content is
`userDurable` until explicit authorized deletion. A postcommit promotion
receipt never appears inside its own precommit envelope. A crash between the
K3 commit and Artifact materialization is repaired from the K3-owned canonical
bytes; it cannot mint different receipt bytes. Cross-owner readers and
publication remain gated while materialization is pending, except that the K3
repair path may use those canonical bytes solely to complete the historical
put.

This protocol applies uniformly to ordinary Main messages, initial Mission
plans, every committed current Mission successor, Whisper branches and
messages, and every adopted SolutionArtifact required to reopen durable
history. Rejected or unadopted candidates remain finite. Every structural
envelope, receipt, binding, and ancestor transitively required by a
`userDurable` head is pinned to a horizon no shorter than that head without
copying a second retention clock.

## Main conversation and Mission graph atomicity

The conversation transcript and Mission graph have separate logical heads but
share the same K3 writer and transaction. Each row owns its own dependency
accumulator. There is no copied/global third closure root.

Every dual-head operation has one semantic identity binding the Workspace,
Session/incarnation, turn operation, input-or-output message ID, prior
conversation head, prior Mission root, exact typed body/envelope/graph content
commitments,
App-Agent selection evidence, and relevant epochs. Lost-reply recovery queries
this identity before attempting any write. Reusing the identity with any
different semantic byte is corruption; a changing physical EventLog sequence
is not part of this semantic identity.

`turnAdmission` and `terminalOutcome` carry and revalidate both
`expectedConversationClosure` and `expectedMissionClosure`, two separately
bounded deltas, and two next roots/frontiers. The one SQL transaction updates
both head/accumulator pairs or neither, while one shared operation receipt binds
the ordered pair of results without becoming a third root. The fixed operation
budget covers the sum of both deltas. `graphProgress` carries only the Mission
closure and SQL-asserts that conversation head and closure are unchanged.
Cross-head delta routing, copied roots, one-sided success, and graph-only
conversation mutation are corruption.

### Turn admission

Before executable allocation, the system reserves, ordinary-puts, binds, and
admits:

- the normalized input body, then the independently admitted
  `BASConversationMessageEnvelope` that references its receipt;
- the immutable `BASMissionTaskGraph` body and its own retention receipt;
- all required precommit retention evidence.

One tagged K3 operation commits the input conversation head and executable
Mission graph root atomically. If either predecessor, retention row, body,
envelope, graph, App-Agent selection, Workspace, epoch, or receipt is stale,
neither head advances.

Every Main turn, including ordinary conversation, has at least a finite
minimal Mission graph before Provider, tool, Sub-agent, or effect allocation.
The graph may contain only understand/respond/close slots, but it is never
omitted. A Whisper turn carries a durable read-only inquiry intent/plan inside
its existing branch envelope with zero executable/effect slots; it does not
mint a second Mission root.

### Graph progress

Internal progress creates immutable Mission graph successors and advances only
the graph root. Every current successor and every adopted Solution dependency
required to reopen it is promoted to `userDurable` in the root CAS. It never
rewrites conversation history.

### Terminal outcome

After neutral verification, the incumbent publication owner prepares a stable
release identity and L14-authorized publication permit without crossing a
possible-start boundary. K3 may bind that already prepared identity and permit;
K3 never invents publication permission. The system then ordinary-puts and
admits:

- the authorized output body, then the independently admitted output envelope;
- the terminal Mission graph successor and its own receipt; and
- the prepared publication intent and stable release identity.

One tagged K3 operation commits the output conversation head and terminal
Mission graph root atomically and promotes adopted bodies to `userDurable`.
That commit records `preparedForPublication`; it does not assert that the user
has seen the reply. Only then may the incumbent publication owner cross
possible-start. The host transcript projects the reply as `visiblePublished`
only after reopening the publication/delivery receipt for the same release
identity. Until then it shows a bounded pending/recovering state without
revealing the prepared reply bytes. Definite pre-start failure, possible-start
unknown, delivery success, and delivery failure remain owner receipts; they do
not rewrite conversation content or create a second transcript head. If a
crash occurs after possible-start, recovery queries or reconciles the same
release identity and never emits a replacement reply.

`preparedForPublication` is durable intent, not a user-observed utterance.
Until a matching delivery-success receipt is reopened, the reply bytes are
excluded from user-seen history, the next `BASContextCompiler` input, memory,
retrieval, recognition, causal/outcome evidence, reward, learning, and export.
If new input arrives while delivery is unresolved, the turn either waits for
reconciliation or receives only a content-free pending/failure fact; it never
receives the prepared reply bytes. Definite pre-start failure never becomes
visible. Possible-start unknown remains query/reconcile-only under the same
release identity.

Task 2 versions the incumbent `BASMissionTaskGraphRootAdvanceRequest` and
`Receipt` in place with one strict closed `BASMissionCommitKind` tagged union:
`turnAdmission`, `graphProgress`, or `terminalOutcome`. The existing
`advanceMissionTaskGraphRoot` K3 method is the only write entry for all three
tags. A second conversation-commit method, writer, SQL statement family, or
compatibility fallback is forbidden. Each tag has an exact associated contained
payload and rejects fields belonging to another tag.

## Inquiry concurrency

Each Whisper branch owns its transcript predecessor. It does not own or freeze
the global EventLog sequence as semantic identity.

Every append first queries one unique adoption key
`(branchRefArtifactID, sessionIncarnation, requestIdempotencyID)`. The key does
not contain the branch predecessor, body/envelope content commitment, physical EventLog
head, or caller display-only `branchID`. The first accepted row immutably binds
the branch-ref Artifact commitment, Workspace, App-Agent selection, logical branch
predecessor, message ID, typed body/envelope content commitments, retention
identities, and append operation row.

- If committed, a byte-equal lookup returns the original append receipt and the
  unique retention-promotion disposition/receipt for that message, even when a
  caller has already observed the successor branch head after a lost reply.
- If absent and only the physical global head changed, retry the K3 transaction
  using the same body, retention row, envelope, adoption key, and branch
  predecessor.
- If the same adoption key carries a different branch predecessor, message/body
  content commitment, scope, read set, epoch, or semantic bytes, reject as corruption or
  stale currentness. Only a genuinely new request/idempotency ID may append from
  the new logical branch head.

The old `expectedK3Head` is removed from the semantic operation identity and stable
idempotency identity. A retry may carry a fresh physical CAS-attempt head, but
that value has no semantic authority. Main and Whisper operations may
serialize through the same physical writer,
but neither advances the other's logical head. A Main-head advance cannot
expand an inquiry's pinned read set. An inquiry append cannot mutate Main,
memory, learning, Automation, publication, or effect state.

A branch-local answer is not an invisible publication bypass. Its exact bytes
pass neutral verification, bounded presentation, and post-style verification;
the body, retention promotion, envelope, and branch-head CAS complete before a
host read-only projection displays it. This grants no Main-line or external
publication, tool, effect, spawn, memory, or learning right.

Promoting an inquiry message into Main never merges heads. It creates a fresh
normalized Main input event and a new Main Attempt under the ordinary
dual-head protocol, with explicit user authorization and provenance back to
the immutable inquiry message.

## Continuity and checkpoint ancestry

`ContextContinuityManifest` is a read-only projection over already committed
ancestors. It may include the current Main conversation head, Mission graph
root, committed SolutionArtifacts, semantic snapshot, owner receipts, pending
obligations, and an optional prior checkpoint coordinate.

`targetContinuationCheckpointArtifactID`, when present, must reference a
strictly lower generation that existed before manifest construction. It cannot
reference the enclosing checkpoint, an equal generation, or a future
checkpoint. Transaction-external preflight verifies the manifest's immediate
strict ancestors, predecessor closure commitment, and bounded delta using a
node/depth/byte budget, visited set, digest equality, generation monotonicity,
duplicate-edge rejection, and overflow-safe arithmetic. A paginated
certification walk may traverse the complete manifest, checkpoint, graph,
Solution, and owner-reference history outside the foreground writer.

The checkpoint install transaction performs no Artifact reopen and no recursive
walk. It synchronously rechecks the validated snapshot's current K3
head/revision/epoch vector, predecessor closure root, retention decisions, and
bounded delta, then commits the new checkpoint head and closure commitment.
It never treats a manifest assertion as an owner/retention receipt and never
awaits while its SQL transaction is open.

## Causal and graph discipline

`BASMissionTaskGraph` owns durable objective/progress lineage;
`BASSemanticTurnDAG` owns one Attempt's frozen execution topology. They may
reference each other only through earlier committed coordinates and never form
a bidirectional Artifact cycle. A dynamic turn may fill, skip, order, or
parallelize predeclared finite slots; it cannot append a new role, authority,
capability, or unbounded node at runtime.

Execution dependency, claim support, and world causation remain three distinct
relations. A scheduling edge is not evidence that a claim is true; a citation
is not a causal edge; an explanation is a projection over receipts and cannot
create any of them. Ontology refinement may add a candidate under the existing
schema-governance path, but it cannot smuggle authority through a generic
“related to,” confidence, or free-energy scalar.

## Per-conversation context engineering

There is no global mutable context window. Each Main conversation, Whisper
branch, Sub-agent slot, and Provider attempt has a distinct purpose-limited
capsule, profile, budget, read set, cache identity, and currentness proof. A
shared source Artifact does not imply shared hidden state, KV, summary, or
authority.

Every committed turn performs bounded maintenance before the next Attempt:
deduplicate, update lexical/FTS and admitted dense/rerank indexes, refresh
temporal/entity links, expire stale projections, and rebuild only affected
summary nodes. The sole `BASContextCompiler` then recompiles the next snapshot
within that conversation's current model/profile budget. It does not wait for
the context window to become full, and compaction never deletes or rewrites the
durable source history.

W0 derives a complete compile/render/fingerprint and Provider-election callsite
inventory. `ContextCompilerCore`, `CognitionKernelCore`,
`SemanticCompilerCore`, `BASLLMPromptCompiler`, extraction engines, legacy
context builders, and adapter-local prompt assembly receive an exact
delegate/migration/retire disposition. W3 produces one canonical
`BASContextCompiler` receipt and byte sequence; downstream components may only
project or transport those bytes and cannot render, drop, compact, fingerprint,
or reinterpret context again.

Likewise, `BASOrganRegistry` and compatibility registries become immutable
capability inventories. W4's admitted execution plan binds one concrete Provider
identity before adapter allocation. Registration recency, adapter-local default,
endpoint-local registry construction, model catalog default, or fallback
cannot re-elect or swap that identity. A missing selected Provider is typed
unavailable and returns to a fresh governed plan rather than choosing another
adapter inside the current Attempt.

Granite embedding and KaLM reranking are distinct derived retrieval roles, not
optional decorations that can silently disappear. Their absence yields a
typed coverage deficit and permits only the explicitly admitted lexical/search
degradation. Embeddings, rerank scores, summaries, and compressed projections
remain rebuildable evidence aids; source Artifacts, ClaimSupportMap,
WorldClaimSet, causal edges, and owner receipts remain truth.

## Work and Automation continuity

Work Space and Automation Space are read/write projections over the same
Artifact/K3/Mission authorities, not new databases, schedulers, or task
managers. Conversation plans, scheduled definitions, skill declarations, run
receipts, recovery state, causal history, and user-visible results retain their
existing owner identities and remain reopenable after interruption.

Every Automation firing creates a stable run identity and commits its finite
Mission graph before allocation. Recurrence, timezone/DST, offline catch-up,
overlap, retry, approval, and cancellation are deterministic inputs to that
same graph and K3 transaction. A signed declarative skill may propose typed
capabilities; it cannot load JIT code, bypass K4, or call a tool/effect outside
the ordinary possible-start protocol. Recovery resumes committed nodes and
queries possibly started operations; it never silently creates a replacement
run.

Shell and tool work use the incumbent durable recovery manifest: stable
invocation identity, sanitized executable/argv/environment/cwd, admitted input
Artifacts, accepted output/transcript prefix, possible-start marker, owner
receipt, and recovery disposition. Secrets and ambient handles are excluded.
A dead PTY is not recreated; recovery reopens the committed prefix and either
resumes a supported same invocation, queries/reconciles it, or reports typed
unavailable without redispatch.

The ordinary user projection exposes only meaningful states such as checking,
ready, running, can continue, recovering, waiting, needs confirmation, blocked,
and complete. Tool paths, nonces, K3 heads, runner flags, and internal admission
mechanics remain evidence, not user chores.

## Publication, Provider, tool, and lifecycle possible-start

An audit append, signature check, in-memory nonce/spend set, returned Swift
value, timeout, or successful adapter call is not terminal truth. Publication,
remote Provider handoff, tool/effect execution, external export, and Apple
lifecycle submission each use the incumbent owner for that boundary and one
closed durable state machine. Its sealed owner-outbox row is an implementation
row in that incumbent owner journal, not an Artifact payload, K3 message store,
second head, or new Store:

1. K3 commits a stable semantic operation identity, typed request content
   commitment, exact boundary-owner identity, current epochs, finite
   `preStartDeadline`, nonextendable `handoffClaimDeadline`, admitted operation
   maximum, fixed minimum handoff-claim slack, lawful retention horizon, and
   `pending` intent under one stable pending-row ID/revision. The claim deadline
   cannot exceed the selected credential expiry, custody-key minimum-
   availability horizon, pre-start deadline, or operation maximum. The pending
   row owns only content-free state and the expected sealed-row binding; it pins
   no request bytes and is the sole cleanup/retry decision;
2. K4 issues/reserves/claims the exact bounded capability and K3 reopens its
   anchor/use evidence, then attaches the exact capability-use ID/revision to
   that pending row before any owner seal;
3. before possible-start, the incumbent boundary owner canonicalizes and seals
   the exact request under the stable operation key into its existing
   `synchronous=FULL` owner journal, then reopens that inert outbox row. The row
   binds the K3 pending-row ID/revision, pre-start deadline, handoff-claim
   deadline, operation maximum, fixed minimum claim slack, exact capability-use
   ID/revision, typed request commitment, current erasure vector, and one immutable
   credential reference `(credentialOwner, principal, handleID, generation,
   credentialClass, leaseOwner, audience, purpose, expiry, revocationEpoch,
   custodyKeyEpoch)`, the authenticated issuer-generation proof identity/digest,
   and the exact K3 credential-use reservation. It contains
   any permitted request bytes only inside sealed owner custody using the same
   confidential commitment, canonical padding, AEAD, and exact outer-length
   invariants as Artifact custody, performs zero
   external I/O, and is never copied into K3. In that same owner-journal COMMIT,
   the owner persists one canonical authenticated row/preflight proof sidecar
   binding the operation, K3 pending-row ID/revision, all three deadlines/
   maximum/slack fields, exact capability-use ID/revision, typed request
   commitment, row revision, owner/store incarnation, custody/credential
   generations, issuer-proof digest, credential-use reservation, root/high-
   water mark, commit coordinate, proof algorithm/key epoch/verifier, and
   signature/MAC. Its
   unsigned body excludes its own digest/tag. Retry reopens those byte-equal
   proof bytes; verify-only material cannot retire while the row may be started
   or reconciled. Same identity/different bytes, credential generation, proof,
   or owner incarnation is corruption;
4. in one `synchronous=FULL` K3 transaction, the sole K3 writer rechecks the
   deletion/revocation/privacy epochs, active credential-generation/use-
   reservation row and issuer-proof digest, and its exact pinned capability-use
   evidence, then commits `possibleStartCommitted` (the only permitted meaning
   of the verb "arm"; no separate persisted `armed` state or receipt exists)
   plus a content-free outbox binding/materialization key. Before `BEGIN`, the
   same K3 actor—not a public caller—must invoke the boundary owner's package-
   private preflight port and receive one unforgeable, non-Codable,
   invocation-local `BASValidatedOwnerOutboxSnapshot`. That snapshot binds the
   semantic operation key, K3 pending-row ID/revision, pre-start deadline,
   handoff-claim deadline, operation maximum, fixed minimum claim slack, exact
   capability-use ID/revision, typed request commitment, row ID/immutable row
   commitment/revision, owner/store identity and incarnation, sealed-custody
   profile/key epoch, erasure vector, exact credential reference, authenticated
   issuer-generation proof, K3 credential-use reservation, owner-journal
   authenticated root/high-water mark and rollback anchor, proof algorithm/key
   epoch/verifier, handoff-claim deadline/custody availability, and proof digest.
   After `BEGIN`, K3 reads no owner database,
   K4 service, Keychain, file, network, or actor; it synchronously rechecks only
   its own complete revision vector and cryptographically verifies the
   persisted owner proof/snapshot against the admitted verifier identity. It
   byte-compares every pending/deadline/maximum/slack/capability field with its
   own current row rather than accepting an owner-selected extension. Using only
   its already pinned K1 trusted-time coordinate it also requires
   `commitTime + minimumClaimSlack <= handoffClaimDeadline <=
   min(preStartDeadline, operationMaximum, credentialExpiry,
   custodyKeyAvailabilityBound)`. Prompt, message, secret, credential, and
   ordinary request bytes never enter K3;
5. that COMMIT is the irreversible possible-start linearization point. Before
   taking its own journal lease or beginning SQL, the sole owner invokes one
   package-private K3 read-only preflight and obtains an unforgeable,
   non-Codable, invocation-local `BASValidatedK3PossibleStartSnapshot`. It binds
   the immutable possible-start decision row/revision, semantic operation key,
   exact boundary owner and sealed-row/proof digest, K3 authenticated historical
   root/HWM/rollback-anchor membership, K4 capability-use identity, exact
   credential-generation/issuer-proof identity, and the deadline/maximum/slack
   fields. After acquiring its own lease the owner
   performs no K3 call or `await`; its short transaction cryptographically
   verifies that proof, rechecks its local sealed row/revision and absent claim,
   and invokes the owner's admitted synchronous commit-time K1 primitive as the
   final conditional mutation. That primitive atomically chooses exactly one
   branch under the same single-writer lease: it durably commits a handoff claim
   containing the K3 proof identity/digest and authenticated
   `claimLinearizedAt`, with
   `claimLinearizedAt < handoffClaimDeadline <= min(preStartDeadline,
   operationMaximum, credentialExpiry, custodyKeyAvailabilityBound)`, or it
   commits an authenticated `expiredDefiniteNonStart` row with no claim. There
   is no check-then-later-COMMIT gap: a backend unable to bind its durability
   linearization coordinate to that conditional commit is typed unavailable.
   The K1 read is synchronous, rollback-protected, overflow-checked, and performs
   no file/network/actor I/O or `await`; clock rollback fails closed. Missing or
   foreign proof leaves the row inert. Only a committed, in-bound claim may hand
   the byte-identical request to the one adapter at most once.
   A crash after the durable handoff claim is indeterminate rather than
   permission to claim or send again unless the external API can query the same
   ID;
6. observed and terminal owner receipts bind the same identity; and
7. after `possibleStartCommitted`, restart performs lookup/query/reconcile under
   that identity only. No re-mint, fallback adapter, new session, or resend is
   legal.

The owner-outbox row has a closed lifecycle. Before
`possibleStartCommitted`, the K3 pending row pins it until a definite pre-start
cancel/expiry tombstone or current deletion fence; only then may the owner erase
the sealed row/key and acknowledge cleanup. After `possibleStartCommitted`, the
exact row and minimum same-ID reconcile material remain pinned through the
handoff claim, terminal/indeterminate policy horizon, external-copy obligation,
and deletion acknowledgement. Deletion may immediately fence result adoption
and destroy every key not needed by an already-linearized exact handoff, but it
cannot simultaneously require that handoff and destroy the one immutable
credential/custody generation needed to perform it. The operation policy must
choose and record one outcome: definite pre-start cancellation, or same-ID
handoff/reconcile under the already committed authorization. Generic TTL,
credential re-resolution, or owner-journal compaction cannot decide this.
If the authenticated owner journal proves that the claim deadline passed with
no handoff claim, the exact operation closes as `expiredDefiniteNonStart` and no
adapter call occurred; it is never revived or resent. Once a handoff claim
exists, crash or deadline passage is indeterminate/query-reconcile-only even if
the syscall cannot be proved. Credential rotation cannot extend the original
deadline or substitute a generation after `possibleStartCommitted`.

Task 2 atomically removes request-outbox ownership from
`state.k3-control-nucleus` and replaces any “K3 sole outbox writer” wording.
K3 owns only `pending`, the content-free sealed-row binding, and
`possibleStartCommitted`. The existing `release.spool-publication` and
`effect.zone-c-saga` journal owners own the exact immutable sealed-request/
outcome rows and physical handoff claims described below; Provider and Apple
platform owners retain only their descriptor/adapter/evidence roles. No generic
`OutboxStore`, `OutboxManager`, second replay bit, or caller-written row is
introduced.

The boundary name is not prose or a new-owner placeholder. Task 2 freezes this
closed `BASBoundaryOwnerID` mapping and updates the existing Owner Ledger rows,
path manifests, and active-plan wording in the same transplant:

- `visiblePublication` → `release.spool-publication` →
  `BehavioralAISubstrate/Sources/BASMemory/BASPublicationJournalSQLiteStorage.swift`
  → sole physical `BASResponseReleaseCoordinator`;
- `zoneCEffect`, `externalExport`, `remoteProvider`, and
  `appleLifecycleOpportunity` → `effect.zone-c-saga` →
  `BehavioralAISubstrate/Sources/BASEffectBroker/BASEffectBrokerSQLiteStorage.swift`
  → sole journal/handoff actor `BASEffectBroker`. The four closed operation
  kinds share only physical external-handoff durability and have disjoint field,
  result, and policy presence matrices. `remoteProvider` consumes the exact
  Provider/Attempt/ordinal binding selected solely by W4
  `execution.plan-provider-router`, reopened and frozen by K3, and calls the
  bound `BASProviderAttemptExecutor` exactly once. W4 alone owns route,
  Provider, and ordinal election. K3 owns only persistence of that immutable
  binding plus claim/currentness/idempotency/adoption/terminal transitions.
  Post-start work is same-ID query/reconcile; any alternative Provider, ordinal,
  or retry requires a fresh governed W4 plan.
  `appleLifecycleOpportunity` calls only the injected sole
  `AppleBGTaskSchedulerBridge` and cannot create scheduler policy. Provider,
  export, and lifecycle outcomes cannot masquerade as Zone-C state mutation.

This reuses the two already allowed journal creations and their existing
owners/M permissions; it adds no Provider/BG journal, third physical database,
logical owner, or generic outbox abstraction. `provider.package-boundary`
continues to own package/descriptor/physical-adapter constraints and
`platform.ios27` continues to own entitlement/composition evidence, but neither
writes handoff rows. A missing broker/journal is `approved_missing`/unavailable,
never permission to fall back to K3 request bytes or an adapter-local map.

Credential authority is independently closed, never a free `String`. The
`BASCredentialOwnerID` issuer/custodian map is: Artifact commitment/custody keys
→ `artifact.mesh`; K4 grant/warrant material →
`sovereign.k4-durable-lifecycle`; and signing keys plus publication/Provider/
tool/export external secret material → `trust.algorithm-agile-manifest` under
distinct closed credential-class tags. Apple entitlement/account eligibility is
not secret-key custody: its signed evidence remains under `platform.ios27` and
cannot supply ambient credentials. Use leases are owned by the exact boundary
journal—publication by `release.spool-publication`, every other external
handoff by `effect.zone-c-saga`—and bind the immutable issuer handle/generation;
a lease owner cannot issue or rotate the secret.

Task 2 extends only those existing ledger rows and paths with the exact issue,
rotate, revoke, delete, and lease writer plus forbidden alias/default source;
owner and M/create cardinalities remain unchanged. Every rotation mints a
monotonic generation, advances the K3 revocation fence before successor use,
and preserves the verify/reconcile material required by an earlier
`possibleStartCommitted` operation. Raw headers, “current credential” lookup,
Keychain aliases without this owner/class/generation, and a new
`CredentialManager` are forbidden.

Cross-owner credential use has one closed generation protocol. The issuer first
commits an immutable authenticated generation descriptor/proof under its mapped
owner; K3 obtains that proof outside SQL and records only its identity/digest,
generation, credential class, issuer, current revocation epoch, and
`active | fencing | draining | retired` state in existing content-free
credential implementation rows. Before a boundary journal seals a request, K3
must reserve a use against an `active` generation. The boundary owner commits an
immutable lease plus issuer-proof identity in its own journal, and a short K3
transaction rechecks its generation row/epoch and pins that exact lease. No
transaction or owner lease spans the issuer, boundary journal, or K3 preflight.

Rotation, revocation, and retirement are ordered, never best-effort: K3 first
changes the generation to `fencing` so new reservations and uncommitted
possible-start decisions fail; it then paginates and proves closure of pending
reservations and both boundary-owner lease/claim/outcome lanes. Pre-start rows
are cancelled or erased; a generation already referenced by
`possibleStartCommitted` retains only the exact handoff/reconcile material until
its fixed horizon closes. The issuer then commits authenticated destroy/retire
acknowledgement, after which K3 closes the old generation and may activate the
successor. An issuer cannot destroy a generation before that drain, and a lease
owner cannot keep it alive by minting or extending a local alias. Missing owner
coverage remains `draining`/typed unavailable rather than key-retirement
livelock or unsafe reuse.

There is no cross-database `armed → journal` authority gap. K3 owns the mutable
possible-start fact; the boundary owner owns its immutable request/outcome
receipts and physical adapter, not a second replay decision. If deletion or
revocation commits first, step 4 fails and no adapter call is legal. If step 4
commits first, later deletion cannot pretend to retract an already authorized
external start; it immediately blocks result adoption, later use, and every
not-yet-committed successor while the original operation remains same-ID
reconcile-only.
The owner journal uses `synchronous=FULL` and one owner-specific single-writer seam.
Its rows and root are authenticated and externally rollback-anchored by the
same anti-rollback protocol as K3; a valid SQLite rewrite or an older internally
consistent journal snapshot is not accepted as absence. The validated snapshot
is never a public request parameter, capability, or reusable bearer token.
When an external system exposes no terminal-query API, an unknown post-start
state remains typed indeterminate and blocks replacement execution. A caller
cannot reinterpret `providerUnavailable`, timeout, cancellation, or process
death as proof of pre-start failure.

The existing public `BASCognitiveBrain`/turn-engine raw result becomes an
internal proposal/result body. A host-visible reply is obtainable only from the
incumbent publication coordinator after the matching delivery-success receipt;
direct result-to-UI call graph reachability is zero. An audit row never seeds a
generic `alreadyProcessed` result. Restart lookup returns the exact pending,
prepared, possible-start, visible, failed, or terminal state and any admitted
body/receipt, rather than rejecting every operation that merely has an audit
entry.

`QinaoRuntime.execute`, `BASToolCallingPlanner`, `BASToolDispatcher`, Provider
adapters, training/export adapters, and Apple bridges are physical mechanisms,
not effect authorities. Production callers can reach them only from the
corresponding broker-issued invocation. The in-memory `consumedBundles`, nonce,
minted-token, handler, or session maps are disposable caches over durable K3/K4
and owner receipts. They never decide replay eligibility after restart.

BackgroundTasks has one classified lifecycle-opportunity bridge. Register,
submit, and cancel use stable lifecycle operation identities and the platform's
query/reconcile evidence when available; the Qinao and BAS bridges cannot both
remain physical callers. This lifecycle seam remains distinct from semantic
Zone-C mutation, but it obeys the same durable-intent-before-possible-start and
no-blind-resend law.

Remote ChatCompletions and PCC requests additionally bind a closed recipient,
canonical destination, transport/TLS posture, model/profile, minimized field
set, consent/privacy/deletion epochs, external-copy lineage, accounting, and
credential handle. Caller-supplied raw authorization headers are neither
Codable nor persistable, and arbitrary URLs are rejected. Secrets, hidden
reasoning, unapproved fields, cookies, redirects, and ambient credentials fail
before K3 `possibleStartCommitted`. A Provider adapter cannot be called directly and cannot decide
its own retry.

## Deletion and resurrection closure

Deletion is a monotonic authority transition, not a best-effort cache cleanup.
The sole K3 transaction first advances deletion/consent/revocation/privacy
epochs, records a stable deletion identity and content-free tombstone, and
revokes read/capability/key use. From that commit onward, source reads, new
derivatives, share use, learning/export, checkpoint restore, cache installation,
and every publication/effect/Provider handoff that has not already committed
`possibleStartCommitted` fail their epoch recheck even while physical cleanup
is unfinished. An exact operation whose possible-start linearization committed
first may still perform its at-most-once fixed outbox handoff and same-ID
reconciliation; deletion cannot rewrite history and pretend it never started.
Its late bytes can produce only permitted content-free outcome evidence and are
barred from adoption, display, learning, export, cache, or successor authority.
If deletion commits first, `possibleStartCommitted` cannot commit.

The lineage inventory covers source bodies, structural payloads, indexes,
embeddings, reranker and summary projections, local exactNative cache, prepared
publication bodies, every boundary-owner sealed request/outbox row and custody/
credential generation, in-flight tool/Provider results, immutable shares,
archives, backups, and every registered external copy. Cleanup acknowledgements are
idempotent descendants of the same deletion identity. Late results may retain
only permitted content-free evidence and cannot resurrect a head, cache,
profile, dataset, or external copy.

A pre-start outbox is fenced, erased, and acknowledged after K3 records definite
pre-start cancellation. A post-`possibleStartCommitted` outbox retains only the
minimum sealed bytes/key generation needed for the already authorized one-shot
handoff or same-ID reconciliation; after terminal/indeterminate lawful horizon
and external acknowledgement it is cryptographically erased. Calling an outbox
an “implementation row” never exempts it from the deletion frontier, key
receipt, or completeness proof.

Enumeration reuses immutable Artifact records and K3 external-copy rows; it does
not add a reverse-index Store or perform an unbounded walk in the deletion
transaction. The existing Artifact SQLite owner maintains a rebuildable
`parentArtifactID → childArtifactID` projection/index in the same transaction as
each immutable put, together with a source-record high-water mark and root. The
projection is acceleration evidence derived from records, never an authority;
index lag or corruption triggers bounded rebuild/quarantine, not a false empty
result.

The epoch/key fence is O(1) and immediate. The existing K3 deletion operation
persists the fence epoch, the committed Artifact outer-anchor generation, and
three separately domain-bound Artifact lanes: immutable identity-record,
`artifact_put_claim_binding`, and custody-generation root/count/high-water mark.
Each lane has a bounded cursor plus included/excluded/erase-ack accumulator.
The operation also persists the paginated descendant work frontier/cursor,
old-epoch reservation/put-claim set, external-copy set, and acknowledgements.
It pages a closed per-owner cleanup lane for every
`BASBoundaryOwnerID`. Each lane stores owner/store/incarnation, committed anchor
generation, fenced authenticated root/high-water mark/row count, and bounded
cursors for pending reservations, sealed outbox rows, credential leases/
generations, handoff claims, outcome rows, external copies, and erase/query/
reconcile acknowledgements. These are implementation rows in the same K3
deletion operation, not one unbounded array or a new Store.

Before freezing the cleanup source roots it resolves every pre-fence
`putClaimed` row, `bindExistingByteEqual` claim binding, pending custody
generation, and K3 outbox reservation against the corresponding Artifact or
owner lane. A late pre-fence committed binding, custody generation, Artifact,
or sealed owner row joins its frontier; an absent/expired claim leaves a
retained tombstone. Each Artifact/owner page is proven transaction-external
against that owner's promoted authenticated root/HWM and registered by a short
K3 SQL transaction after rechecking the fence vector. Completion requires an
empty Artifact/descendant frontier, projection watermark equal to the fenced
identity source root/HWM, exact identity/claim-binding/custody lane cursor,
count, and root equality, every boundary-owner lane cursor at the exact frozen
root/HWM/count, zero unresolved old-epoch reservation/claim/custody generation/
credential lease/handoff, and all required raw-byte/key/external-copy
acknowledgements reopened. A child whose Artifact ID sorts before its parent, a
late pre-fence put/binding/custody generation or outbox seal, projection rebuild,
owner-index lag, forged owner proof, or caller-supplied empty frontier cannot
escape this proof.

`completed` is legal only after the persistent tombstone and every mandatory
local/external acknowledgement have been reopened. Missing, timed-out,
unqueryable, or failed tiers are reported as exact `pending`, `partial`, or
`indeterminate` state; a static list of tier names, an in-memory receipt, or
source-row deletion alone can never claim completion. Revocation cannot erase
bytes already lawfully disclosed to a user, but it synchronously prevents every
future Qinao use and retained plaintext buffer.

## Sub-agent durable milestones

Sub-agent recovery does not create a milestone Store, queue, or head.

One logical Main may allocate only the frozen finite depth-one Sub-agent slots
declared by the Mission graph. Each slot has an independent capsule and budget.
Join logic is evidence- and correlation-aware, discounts shared-source and
common-mode errors, and never treats majority vote, PCC concurrency, or model
agreement as truth or authority.

At a predeclared semantic-node terminal or accepted bounded chunk boundary, a
Sub-agent may ordinary-put a structured non-CoT `BASSolutionArtifactPayload`.
It may
contain claims, evidence, assumptions, uncertainty, counterexamples, status,
and ordinal, but no raw hidden reasoning. A Mission graph successor references
the Artifact, and the sole Mission-root CAS accepts it.

The Mission root is the only progress truth. Recovery reopens accepted
SolutionArtifacts and reruns only graph nodes that have no committed successor.
An external possibly-started operation remains governed by its original owner
receipt and reconciliation protocol.

Each solution has a stable adoption key containing Attempt, frozen slot,
semantic node, and ordinal, excluding the body content commitment. The first
accepted row binds the typed content commitment. Exact replay returns the same
receipt; the same key with a different commitment is corruption. If two
Sub-agents finish from the same Mission
predecessor, the losing CAS first queries this key. If the solution is not
already adopted, it reopens the winning current root and revalidates the
Attempt/generation/epochs, frozen slot membership, and open/not-terminal,
not-cancelled, not-superseded state before constructing a deterministic merge
successor in frozen slot/source order. It neither regenerates nor rewrites the
losing Artifact. A stale or closed loser remains a finite orphan. One ordinal
is adopted at most once.

An unadopted milestone uses `recovery72Hours`. If any current durable Mission
root or conversation transitively depends on it, the same K3 transaction must
promote its lawful content and structural dependencies to `userDurable`.
Rejected candidates remain finite. A separate per-Sub-agent milestone head is
forbidden.

## Long-chain non-drift certification

Single crash cuts are necessary but insufficient. W6 reuses the incumbent
`runtime.replay-manifest` owner, the existing
`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainTurnResultReplayHarnessTests.swift`
suite, `BASAutomationReplayCertificationTests`, and
`BASAutomationFaultMatrixTests`; it creates no second runner, Store, progress
head, scheduler, or recovery authority.

Task 2 contributes exactly one new unique selector to the canonical successor
ledger and the existing W6 nonempty command that already selects this suite,
and marks the exact existing test file above as `Modify` in the W6 candidate
path manifest:

`BehavioralAISubstrateTests.BASEBrainTurnResultReplayHarnessTests/testRepeatedInterruptArchiveCompactionAndRestartPreserveObjectivePlanHeadsContextIdentityAndNextEligibleWork`

It does not replace or rename any predecessor selector. After all adopted
design deltas are assembled, the canonical generator recomputes the total,
per-Wave partition, ordered hash, every `--require-test`, suite/risk mirror, and
missing/extra mutation from the resulting ordered set.

The deterministic contract profile runs at least 128 committed turns and 32
cut/reopen cycles. Its preregistered schedule includes Main input admission,
Mission progress, two independent Sub-agent completions and a losing adoption
CAS, Whisper interleaving, per-turn context maintenance, context compaction,
checkpoint and archive receipt materialization, publication possible-start,
tool/effect possible-start, app background/foreground, and total process-memory
loss. It includes consecutive cuts and at least one cut in every boundary class.

The interrupted and uninterrupted control runs consume the same frozen input,
trusted-clock, entropy, Provider, tool/effect, publication, and owner-observation
tape. The deterministic contract profile performs no live external call. Every
reopen uses only Artifact/K3/owner receipts and the original stable operation
identities. It may query or reconcile an operation that possibly started; it
never redispatches it and never reads hidden reasoning or transient Provider
state.

For every cut, history through the last committed boundary must be a byte- and
receipt-verified pre-cut EventLog prefix of the recovered run. Before the next
ordinary semantic operation, any divergent suffix may contain only the closed
recovery dispositions already admitted for that boundary: idempotent
lookup/reopen, pending-receipt materialization, same-identity query/reconcile,
deterministic rebuild of derived projections, or typed unavailable. Every such
row binds the original stable operation, predecessor HWM/row version/epochs,
owner receipt, and exact-once fold. The suffix cannot contain an extra domain-
head CAS, budget debit, capability grant/use, retention disposition, epoch
advance, Provider call, publication, tool/effect dispatch, compensation, or
rollback not present in the frozen observation tape. A swapped, missing,
duplicated, foreign-identity, or non-foldable row fails. Matching final roots
alone is insufficient. After the recovery barrier, later ordinary transitions
map one-to-one to the control run's stable semantic identities even when their
physical EventLog sequence numbers differ.

After every cycle the harness compares the exact objective and constraints,
current conversation and Mission logical heads, App-Agent/Workspace/Session/
Attempt identities, accepted Solution lineage, current context profile and read
set, cache-scope identity plus eligibility/disposition, user-visible transcript,
pending obligations, uncertainty/blockers, and next eligible work. Optional
cache-body Artifact IDs or presence are acceleration state and are not equality
truth. The verified recovery suffix has a content-free projection, and all
semantic roots satisfy the same closed correctness manifest. Compaction may
replace only derived projections; it may not delete or rewrite source truth.
The final replay contains no lost or duplicated message, plan node, Sub-agent
adoption, Provider call, publication, tool/effect invocation, or user-visible
result.

## Local checkpoint acceleration

Remote API and PCC hidden state are unavailable and never persisted. Local
Qinao-owned model state has a narrower exception.

Only an `exactNative` local cache image may be persisted, and only when it is:

- encrypted under a dedicated erasure domain;
- bound to Workspace, Window, Session, App Agent, role, Attempt, model,
  material, profile, compiled context, tokenizer, sampler, accepted output,
  restoration, capability, policy, deletion, kill, and deadline currentness;
- retained as `recovery72Hours`, never as truth or user memory;
- independently deletable and unable to cross Agent, Attempt, model, or
  profile boundaries;
- proven to reproduce exactly the same accepted prefix; and
- accompanied by a cache-persistence eligibility proof over the complete
  compiled context.

The incumbent caller-controlled `sessionID` registry and public
`persistSession(...to: URL, quantizeKV:)`/`restore(...from: URL)` API are retired
from production in the same W4 candidate. No caller chooses a cache path or
restores another scope's bytes. The sole cache vault accepts a strict composite
identity containing Workspace, App-Agent root, Session/incarnation, Attempt,
role, model/material/profile, typed compiled-context commitment and public
tokenizer/vocab digests, sampler,
accepted-prefix lineage, sensitivity, retention admission, erasure domain, and
all deletion/capability/kill epochs. Its capacity is admitted by K1; an
`unlimited` default is forbidden.

File protection metadata is defense in depth, not confidentiality authority.
An allowed cache body is envelope-encrypted before filesystem/SQLite write by
the incumbent erasure-key custody path, and a failed encryption, key custody,
Data Protection, retention, or sensitivity step fails before the body is
written. Environment variables cannot disable the production protection path.
Arbitrary external URLs, raw safetensors, caller-supplied cache identities, and
best-effort protection followed by success are Release-unreachable.

That eligibility proof rejects any compiled context containing `neverPersist`
secrets, remote-only state, private handles, hidden reasoning, or a source that
forbids derivative persistence. The cache is registered as a descendant of
every source Artifact and erasure domain. Deletion, consent withdrawal,
privacy/security reclassification, or currentness loss in any source makes the
cache unreadable immediately. The no-language and no-learned physical closures
contain no cache producer or materializer.

The accepted token prefix must equal the exact tokenizer projection of the
authorized accepted visible-output prefix. It excludes prompt bytes, hidden
reasoning, unaccepted tokens, secrets, and speculative continuations.

Lossy, Q4, MTP, or otherwise non-exact cache state remains in-process and
disposable unless a future independently certified use is admitted. It cannot
be a durable recovery body merely because a codec exists. Loss of every cache
must still permit deterministic recompile/prefill from committed accepted
prefixes.

Task 2 must atomically repair the currently planned W1 wire before first
admission. Governed `BASCacheCheckpointEncoding` accepts only `exactNative`.
`BASContinuationCheckpointRef` keeps accepted-prefix recovery truth and makes
the cache-identity reference present only for an exactNative cache lineage;
`BASProviderCheckpointReceipt` is produced only after exact verification.
Recompile-from-prefix carries zero cache body, zero cache retention admission,
zero cache identity, and zero provider checkpoint receipt. Existing
`.lossyHint` and `.lossyHintRecompileOnly` spellings move to a transient,
non-Codable acceleration observation/route diagnostic and can never install a
continuation head. Decoder, factory, Artifact put, and retention admission all
reject non-exact cache bodies before I/O.

## Atomic migration bundle A: authority and persistence spine

Task 2 first maps every symbol, path, owner, fixture, historical-put row, and
selector into the controlled documents. W0 inventories every current mutable
writer and bypass, including Artifact heads, EventLog/Federated/Routed writers,
UserState/Routed stores, direct publication results, Provider/tool dispatch,
in-memory K4 spend/nonce state, and both BGTask bridges. No path omitted from
that bidirectional inventory may survive as a production fallback. W1 then
freezes:

- the generalized retention request and subject;
- the pre-put pending-retention reservation, reserved-put authorization, trusted
  provisional horizon, admission pending-materialization repair, and crash
  states;
- transient `BASPreparedArtifactIdentity`, authenticated
  `BASReservedArtifactPutAuthorization`, and non-escaping
  `BASAuthorizedArtifactReadLease` shapes and access control;
- the closed `BASArtifactContentCommitment` taxonomy, authenticated
  `BASValidatedOwnerOutboxSnapshot` and reciprocal
  `BASValidatedK3PossibleStartSnapshot` preflight proof shapes, content-free
  `pending`→`possibleStartCommitted` K3 facts, and strict rule that each W5/W6
  boundary kind uses its exactly mapped publication/effect journal sealed-row
  implementation without request bytes entering K3;
- `BASConversationMessageEnvelope`;
- the exact pre-receipt `BASMissionTaskGraph` and
  `BASSolutionArtifactPayload` bodies;
- contained `BASSolutionAdoptionBinding` and tagged dual-head commit facts;
- the contained incremental `BASDurableDependencyClosureCommitment`, transient
  `BASValidatedArtifactClosureSnapshot`, K3 implementation-row
  `BASArtifactStructuralClosureCertificateRevision`/`pendingClosureBuild`
  shapes, fixed delta budgets, and no-await lock order;
- the model-neutral portable-archive source-universe epoch, source-snapshot/
  lane, causal-cut, authenticated page-proof/public-verifier bridge/scan-
  outcome, paired content/dependency MMR accumulator and bijection,
  progress-renewed build-retention lease, immutable certified-indexed-subtree,
  and restore baseline/mode/readiness value shapes;
- the exact top-level/contained classification and recursive metadata
  retention rules;
- Main/Mission and Whisper stable semantic operation keys;
- strict ancestor validation;
- the versioned immutable-only production `BASArtifactStorePort`; public
  `headUpdate`, `head`, `BASArtifactHeadCAS`, and the four legacy Artifact-head
  purposes become package-private migration evidence only; and
- encrypted-at-rest Artifact content as a prerequisite for every confidential,
  conversation, persona, plan, solution, checkpoint, or recovery body. A
  confidentiality label, HMAC identity, `encryptionKeyID == nil`, or filesystem
  protection alone is rejected;
- exact v1/v2 identity domains, append-only custody-generation row shape,
  bounded migration proof-map shape, and contained
  `BASArtifactV1ToV2MigrationCertificate`; and
- current/future fixtures and registry classifications.

The content commitment, prepared identity, reserved-put authorization, authorized-read lease,
custody-generation descriptor, and v1/v2 migration-certificate value contracts
live in `BASRuntimeCore/BASArtifactMeshCore.swift` under the incumbent
`artifact.mesh` owner. The dependency commitment, structural certificate,
Artifact preflight, model-neutral owner-outbox preflight protocol/snapshot,
staged-build, and head-operation value contracts live in
`BASRuntimeCore/BASSemanticStateLakeContracts.swift` under
`state.snapshot-contracts`; their mutable rows remain solely owned by
`state.k3-control-nucleus`. This distribution adds no reverse package edge or
second row authority.

For a confidential kind, canonical plaintext is only a transient owner-factory
input. Task 2 freezes distinct v1/v2 canonicalization, integrity-algorithm, and
domain identifiers. The v2 stable Artifact-ID preimage never contains a bare
plaintext digest or exact plaintext length. It binds an immutable keyed,
domain-separated content commitment over the erasure-domain secret salt,
schema/scope, canonical plaintext digest, and exact length, plus schema/version,
classification, scope/subject, erasure-domain identity, and parent commitments.
The public immutable identity metadata exposes only that keyed commitment and a
coarse padded-length class; the exact digest and exact length live only inside
the encrypted custody envelope. Thus a database or metadata reader cannot run
an offline dictionary against a short reply, persona, plan, or secret. The
preimage does not include plaintext bytes, ciphertext/sealed digest, AEAD
nonce/profile, opaque content/custody key reference or generation, or custody
location. Content/custody re-encryption and content-key rotation cannot change
the stable v2 ID within its fixed identity domain, erasure-domain commitment,
and commitment-key epoch. Commitment-key rotation never rewrites an existing
ID: the referenced epoch remains verifiable for existing IDs and only new
Artifacts use the successor epoch, unless an independently admitted whole-
domain successor migration is performed. The immutable identity record stores
only those stable non-disclosing commitments. In the same Artifact SQLite owner,
append-only custody-generation
rows `(artifactID, generation, envelopeDigest)` hold a v2 envelope and
ciphertext binding the v2 Artifact ID as AAD, AEAD profile, opaque key
generation, the exact plaintext digest/length, and record-integrity metadata;
they are not a Store or head. The
existing K3 custody/key epoch row is the sole selector of the readable
generation. `read` returns immutable identity metadata and sealed bytes for that
exact generation, while only `readAuthorized` may expose a bounded plaintext
through a transient, non-Codable, non-escaping `BASAuthorizedArtifactReadLease`
after current K4/K3/key checks. It pre/post-checks epochs, zeroizes its buffer at
scope end, and no derivative may commit, publish, export, cache, or cross an
effect boundary without another currentness check. Public-inline content is a closed explicit
classification and can never be selected for conversation, persona, plan,
Solution, checkpoint, Provider, secret, or recovery bytes.

The padded-length class is a physical ciphertext invariant, not cosmetic
metadata. Task 2 freezes one finite, monotonically nondecreasing class table and
one domain-separated canonical padding algorithm per AEAD profile. Canonical
compression, when admitted for a schema, occurs before padding and its exact
compressed length remains only inside the encrypted inner header. The custodian
constructs an inner value `{schema, exactPlaintextLength,
typedPlaintextCommitment, canonicalPlaintext, padding}` whose canonical encoded
length is exactly the selected class, then encrypts that whole value. The outer
record exposes only class ID and the fixed AEAD-overhead-derived ciphertext
length; actual stored BLOB length must equal that value. Unpadded fallback,
plaintext-dependent outer compression, random extra length, a wrong class, or a
ciphertext whose length reveals the inner exact length fails before commit.

The erasure-domain content-commitment salt/key is distinct from the Artifact-ID
commitment key and from the custody-encryption key. It is available only inside
the authorized Artifact custody path and is never returned by metadata reads.
An authorized decrypt recomputes the keyed commitment and exact length before
releasing plaintext. Deletion destroys the content/custody keys and the
erasure-domain commitment salt after fencing current reads; the remaining
identity row can prove only the permitted content-free tombstone and lineage,
not recover or revalidate erased plaintext. Existing Artifact-ID bytes remain
verifiable because they commit to the already stored keyed-commitment value;
they do not require disclosure of the destroyed salt. Domain or salt migration
therefore uses an admitted successor Artifact rather than silently rewriting an
existing identity.

Every derived Artifact additionally binds a fixed-fan-in, canonical ordered set
of its direct parents' erasure-domain commitments and a recursively derived
`erasureClosureRoot`. K3 owns a current erasure epoch/root per admitted scope;
the custody lease binds the bounded set of scope roots needed by that Artifact.
A source deletion first advances the affected scope epoch/root, so any old
derivative witness fails an O(1), transaction-local `readAuthorized` check even
while descendant cleanup is still pending. Custody keys for a persistable
derivative are non-exportably AND-bound to its own erasure handle and the direct
parent handles; a standalone reusable derived key is never persisted. If the
platform cannot enforce that binding, durable derivative persistence is typed
unavailable and the value remains rebuildable transient state. Revalidation is
outside the read path and uses the bounded structural-closure builder; only a
new successor custody generation/Artifact with current roots may become
readable. A derivative spanning more scopes or direct parents than the closed
fan-in budget is rejected rather than weakening deletion.

Re-encryption appends and reopens a new custody generation first. One K3
transaction then rechecks epochs, flips the selected generation, and records its
receipt; only afterward may the old generation be key-revoked and cleaned. A
crash before the flip leaves an unselected collectable envelope; a crash after
the flip reads only the new generation and never falls back. Immutable Artifact
identity bytes are never updated in place.

The v1 plaintext-bearing identity/record remains readable only by a pinned
historical verifier and migration capability; it is never rewritten in place
under the same Artifact ID. W2 first completes the bounded legacy-head fence and
K3-only activation below while the Host remains closed. It then uses existing K3
migration-operation rows to build a complete v2 successor DAG bottom-up in
bounded chunks. W0 first proves whether each v1 Artifact ID has exactly one
canonical source scope/erasure domain. If it does, that fact is frozen in the
source inventory. If one v1 identity appears in multiple independent deletion
domains or schema-role edge occurrences, migration uses a bounded 1:N proof map
keyed by `(v1ArtifactID, canonicalSourceScope, erasureDomain,
schemaRoleOrReferrerEdge)`; every immutable referrer edge resolves with that
full key, and a bare `resolve(v1ArtifactID)` is ambiguous and rejected. Each
immutable v1 body occurrence and immutable referrer receives the corresponding
v2 successor under one stable semantic migration key. Every chunk binds the
frozen source root/high-water mark, cursor, exact occurrence/edge count, v1→v2
proof-map accumulator, and structural certificates but is not currentness.
High fan-out cannot expand one writer transaction.

An erasure scope is no coarser than the smallest independently deletable
subject fixed by policy. Two App-Agents, Sessions, or consent/deletion domains
cannot share one custody/commitment secret merely to reduce row count. Cross-
domain read reuse remains an immutable-share capability over the canonical
source custody; migration does not duplicate authority or let deletion in one
scope erase or preserve another by alias.

Only after the staged source count/root proves zero reachable unmigrated v1
referrer does one O(1) `synchronous=FULL` K3 transaction seal the complete proof-
map root and flip the migration/currentness generation. Before that flip v1
alone is current; after it v2 alone is current and ordinary reads have no v1
fallback. Historical K3 receipts that name v1 use a K3-owned read-only resolution
proof. Before any v1 commitment-key epoch can retire, the Tasks-0–2-admitted
K3/audit migration-verifier profile under `state.k3-control-nucleus` signs an immutable
`BASArtifactV1ToV2MigrationCertificate`, contained in the K3 migration row and
portable replay manifest. It contains a domain-separated, migration-verifier-
keyed `v1IdentityCommitment`; no raw SHA-like digest of plaintext-bearing v1
identity bytes is serialized into K3, an archive, a receipt, or the certificate.
The signature binds that opaque commitment, old Artifact ID/algorithm/key
epoch, full scope/erasure/edge occurrence key, v2 ID/keyed content commitment,
source/high-water/map roots, and verifier identity. Historical verification
checks that certificate rather than requiring a destroyed key to recompute the
old HMAC; a retained old key may only cross-check it. Its verify-only public-key
chain and opaque commitment remain available after permitted migration-secret
retirement; verification never claims to recompute erased plaintext or the old
HMAC without its retained key. The certificate is not a head or alternate
ordinary read path.
It never calls, imports, or consumes a W6 `runtime.certification` receipt; W6
only later reopens the already admitted certificate for replay evidence.
Only after the flip, proof-map/source-HWM closure, all certificates, WAL
acknowledgement, and key receipts may v1 plaintext/WAL/content keys and
unreferenced commitment-key epochs be erased. Crash/retry resumes the same bounded migration row and never creates
dual currentness or an in-place ID mismatch. Any predecessor SQL migration that
mutates v1 identity bytes in place is replaced by this successor protocol.

W2 atomically implements retention reservation/admission, historical receipts,
staged promotion, dependency-closure commitments, main/mission/inquiry logical-
head CAS, lost-reply lookup, orphan handling, deletion races, and corruption
handling in the sole K3 writer. It also installs the planned generic
archive-cut/page/MMR/build-lease/certified-subtree implementation rows and short
transactions in the existing `state.k3-control-nucleus`/
`BASSQLiteEventLogStorage` owner. Those W2 rows consume only the model-neutral W1
contracts and do not import or instantiate the future W6 manifest codec. W6
later defines and composes the sole `BASArchitectureReplayManifest chunk | root`
first wire under `runtime.replay-manifest`; it does not invent K3 persistence.
Task 2 adds these exact phases, paths, ExtensionGate dispositions, Owner-Ledger
evidence/forbidden fields, and selectors atomically while preserving
`29/14/14/7`. All transaction methods use transaction-external Artifact/owner
preflight and synchronous SQL-only commit.

The legacy-head cutover has one closed crash-recoverable sequence and no dual-
write interval:

1. quiesce Host mutation and reject every predecessor binary/version;
2. in the existing Artifact database, verify all rows in the four legacy head
   classes, install a durable write-abort fence, and record one deterministic
   source root, count, and high-water mark;
3. under the existing K3 cutover semantic-operation row, page those rows into
   non-authoritative `pendingHeadCutover` staging rows. Every chunk has fixed
   row/byte/statement/duration budgets and binds source cursor/root plus an
   imported accumulator; it is never served as currentness;
4. in one O(1) `synchronous=FULL` K3 transaction, verify final count/root/high-
   water equality, flip the single cutover activation generation from legacy to
   the staged root, and commit `k3HeadCutoverComplete`;
5. keep the Host closed until the required v2 Artifact and bundle-B privacy
   migration generations are also sealed; after reopening all currentness reads/
   writes use K3; and
6. retain the old table only as read-only migration evidence or remove it in a
   later admitted cleanup.

A crash between staging chunks resumes the exact cursor/accumulator; a crash
after the Artifact fence but before final activation keeps the Host closed and
the staging rows non-authoritative; a crash after K3 COMMIT reopens the K3
receipt and never restores legacy authority. The Owner Ledger keeps the same `artifact.mesh` and
`state.k3-control-nucleus` rows but changes Artifact mutable-state ownership to
none and K3 to the sole head/currentness writer.

EventLog, Federated/Routed EventLog, UserState/Routed store, atom, graph, and
other predecessor mutation ports receive the same bounded staging → O(1)
activation-generation template and migration-reader-only disposition. Content disposition for psychological
UserState rows is supplied by bundle B before the shared cutover; bundle A may
not blindly import it. No old writer, fallback database, `synchronous=NORMAL`
K3 profile, or caller-selected primary remains Release-reachable.

New K3/EventLog rows are bounded typed facts, identities, typed content or
authenticated-byte commitments, epochs, and content-free receipts. Free-form
`payloadJson`, prompt/persona text, ordinary
message bytes, secret values, and hidden reasoning live only in their admitted
encrypted Artifact classifications or are never persisted. Historical
free-form rows are migration/query-only, normalized into typed facts when
provable, or privacy-fenced; they are never copied wholesale into the new K3
truth or learning/export path.

K3/EventLog and each incumbent boundary-owner journal also have one exact
authenticated anti-tamper/anti-rollback chain. The sole K3/EventLog SQLite
writer appends a keyed, domain-separated row/transaction commitment and
cumulative root in the same `synchronous=FULL` transaction; a keyless row chain,
optional integrity check, or syntactically valid SQLite database is not proof.
Each mapped publication/effect journal owner similarly authenticates its own
immutable journal root; K3
does not become its request-byte writer. The existing platform anchor adapter
may store only an opaque generation/root CAS outside the database. It is a
physical rollback-resistant anchor for the incumbent K3 state owner, not a
second logical head, Store, Manager, EventLog writer, or policy authority.

Every journal uses the same closed two-level canonicalization. The inner
successor-root preimage is exactly `rootDomain || predecessorRoot ||
transactionIdentity || orderedDomainRowCommitments || resultingCount ||
resultingHighWaterMark`. The root/cumulative-root metadata row itself, anchor
generation/digest/tag, proof/sidecar bytes and tag, and every field that embeds
the resulting root are type-excluded from `orderedDomainRowCommitments` and
cannot be smuggled in as an opaque extension. The inner root is computed first;
the outer proof sidecar and pending/committed anchor then bind that root/HWM.
Neither outer layer feeds back into the inner preimage. K3/EventLog, Artifact,
and each boundary journal use distinct domains and fixed row-kind allowlists;
iterated fixed-point hashing or candidate-defined exclusions are forbidden.

Each `orderedDomainRowCommitment` leaf is itself closed:
`rowDomain || rowKind || stablePrimaryKey || canonicalSemanticColumns`. Its
preimage type-excludes that row's own commitment/MAC/tag, cumulative-root/
anchor/proof fields, and opaque extension maps. Unknown semantic columns require
a schema successor and fail current decode; an implementation cannot hide an
integrity field inside a free map and then choose whether it participates.

The existing Artifact metadata/anchor generation covers three separately
domain-separated inner accumulators: immutable identity-record root/count/HWM,
`artifact_put_claim_binding` root/count/HWM, and custody-generation root/count/
HWM. Content+binding and `bindExistingByteEqual` transactions atomically append
the applicable binding/root facts before their outer anchor promotion. A
committed anchor generation missing a previously bound claim proof is
quarantine, never permission to synthesize a new binding. This extends the
incumbent Artifact anchor; it does not create another Store or anchor owner.

Anchor rotation uses a closed pending→committed protocol parameterized by the
journal owner. K3/EventLog uses its one non-reentrant K3 mutation lease; each
boundary journal and the Artifact custodian use only their own single-writer
`journalOwnerMutationLease`. No lease or SQL transaction spans a call to another
actor, journal, K4, Keychain, or anchor adapter. K3 obtains an owner preflight
only after that owner has promoted its anchor and released its lease; the owner
never calls K3 while holding its lease.

Within each owner, the pending anchor binds predecessor generation/root,
expected successor generation/root, exact semantic transaction key, and one
authenticated bounded recovery-capsule/delta commitment. The local SQLite
transaction stores the corresponding canonical successor root and recovery
facts. Anchor promotion is that journal's sole visibility point: while pending,
every ordinary local get/reopen/proof is blocked from observing either
candidate, and that owner cannot service a competing mutation. On reopen,
`DB == expected successor` promotes byte-identically; `DB == authenticated
predecessor` may abort the never-visible attempt; every other pairing is
quarantine. Once a committed anchor is at generation `g+1`, a database at `g`,
a recomputed keyless chain, a valid-row rewrite, or an internally consistent
older backup is rollback and fails closed. Verify-only anchor/key material
remains for every live historical proof. If the platform cannot provide the
admitted rollback-resistant CAS/root verifier, the lineage is typed unavailable;
it never silently downgrades to `synchronous=FULL` alone.

Every Release EventLog read uses one throwing, diagnostic-preserving typed port,
not only recovery and migration. Context compilation, UI/history projection,
snapshot/count, replay, learning, export, retention, graph/atom extraction,
federated/routed reads, and ordinary Host paths cannot retain a nonthrowing
compatibility accessor. SQLite open/prepare/step/decoding, checksum, sequence,
replica, empty-backend, or routing errors can never become `[]`, `0`, a fresh
Session, or a missing-history fact. They produce a typed corrupt/unavailable
result, preserve exact diagnostic evidence, quarantine the affected lineage,
and block replay, learning, export, context/head adoption, and any projection
that would misstate absence until independently repaired. An optional
diagnostic callback is observability, not the error channel; `try? ... ?? []`,
`totalCount ?? 0`, and callback-plus-empty fallbacks have zero Release
reachability.

To preserve first compile, W1 may add the typed result/error contract without
removing the predecessor method. W2 then changes the protocol, every conformer,
every Release caller, fixtures, and test doubles in one candidate and makes the
old accessor package-private migration/fixture-only or removes it. Its exact
path manifest includes `BASEventLog.swift`, `BASSQLiteEventLogStorage.swift`,
`BASRoutedEventLogStorage.swift`, `BASFederatedEventLogStorage.swift`,
`BASMemoryAtomReducer.swift`, `BASEventSourcedMemoryAtomStore.swift`,
`BASKnowledgeGraphEventExtractor.swift`, `BASEventReplayRunner.swift`,
`BASBiomimeticCheckpointReplay.swift`, `BASTrainingDataExporter.swift`,
`BASEventLogReplayBundle.swift`, `BASCognitiveOSBundle.swift`, and the complete
machine-derived Release caller/conformer/test-double inventory. W6 proves the
old source symbol and `[]`/`0` corruption fallback are absent from Release
source and call graphs; it does not postpone the API migration.

For migration, Task 2 freezes the predecessor-derived source-role mapping and W0
reopens it, verifies the bytes, and issues the owner receipt selecting one
canonical source chain per Session. Its authoritative order is source identity + session-local
sequence + event ID + explicit predecessor/hash; wall-clock time is metadata,
never causal order. Other backends are replicas and must match that event ID,
bytes, source sequence, and predecessor; same identity/different bytes or a
replica-only fork is corruption. If genuinely independent source chains must be
combined, each row carries stable source identity, source-local sequence, and
explicit causal predecessor/vector. Migration validates the partial order and
uses one canonical topological serialization with a stable source/event
tie-break only among causally concurrent nodes. When cross-source causality or
coverage cannot be proved, it returns `coverageDeficit`/quarantine rather than
inventing an order from timestamp or backend iteration. Multi-copy deletion is
not represented as one SQL transaction: K3 first fences the logical event, then
each copy records
pending/ack/reconcile under the same deletion/external-copy lineage. A partial
backend failure remains visible and cannot be reported as atomic success.

W5 then installs the sole publication and effect/provider journals and removes
every direct-result/direct-dispatch bypass in the same Release candidate. W6
proves process-death cuts across retention reservation, Artifact put/bind,
admission receipt materialization, closure/head commit, publication, Provider,
tool/effect, BGTask, deletion, and terminal reconciliation. No producer or Host
projection is enabled until the relevant complete slice and crash matrix are
admitted.

## Atomic migration bundle B: identity, persona, and privacy

W0 creates a complete, bidirectional disposition inventory for:

- `BASUserState`, SQLite/Rust/routed stores, reducers, builders, restore paths,
  and raw training exporters;
- `personaInstructions`, `personaRef`, both MLX system-message sinks,
  Persona SDK/Studio aliases, Skill/A2A reinjection, comparison paths, and cold
  restart snapshots; and
- every public Agent-spec/warrant/visibility/write-domain/commit-capability
  constructor, persona risk threshold, forbidden-detector bypass, registry
  registration path, and cold-restart authority restoration path; and
- every sample/host signing or Provider credential source, including plaintext
  Application-Support HMAC keys, command-line API keys, raw header maps,
  environment inheritance, logs, snapshots, and Codable restore paths.

W0 serializes that one machine-derived inventory into two checked-in,
non-runtime-authoritative manifests with stable digests:
`LegacyPersonaSourceSinkRecoveryManifest` and
`LegacyUserStateSourceSinkRecoveryManifest`. W1 may declare only their
contained decoder/value shapes. W2 migration, W4 source/callgraph gates, and W6
replay consume the same W0 digests; W6 does not redefine either set.

W1 declares a public, validating, transient, non-Codable, contained
`BASHumanFitProjection` in RuntimeCore. It binds provenance, scope, expiry,
consent, deletion, and confirmed-preference Artifact references. It receives no
independent schema row, Artifact kind, retention admission, or Store.
It never enters a governed Codable packet, Artifact, EventLog row, checkpoint,
database, export, or learning payload. The sole compiler may consume it only
ephemerally. The only persistable “presentation result” is the final governed
user-visible message/spool after the existing L10/L11/L14 path; no reusable
profile, preference, index, cache, or HumanFit bytes are persisted. Existing
governed evidence references mark the transient influence and preserve
learning/export ineligibility unless the user separately confirms a stable
preference. Each fresh Attempt recomputes the projection from current evidence.

Caller-authored persona/Agent values never mint authority. Public
`BASAgentSpec` factories cannot accept arbitrary `writeDomains`, visibility, or
`commitCapability`; a closed signed owner-ledger role contract derives those
fields. A sovereign/persona warrant is an incumbent K4 capability receipt that
binds issuer, subject, exact fields/template digest, Workspace/Session/Attempt,
purpose, epochs, expiry, nonce, and typed request content commitment. A string
ID/reason DTO is not a warrant. Persona detector thresholds are internal finite constants in a
closed range; NaN, infinity, caller thresholds, and values outside `0...1` fail
closed. LOW-tier output is still validated; an allowed template uses an
attested template digest, not a caller-declared visibility exemption.

Signing and Provider credentials are opaque handles issued by the incumbent
credential owner. Apple-platform Release custody uses the admitted Keychain/
Secure-Enclave-backed profile with device/accessibility class bound in evidence;
other platforms use an independently admitted equivalent. Secret bytes never
enter argv, environment, process listings, logs, Codable snapshots, Artifact
payloads, sample Application-Support files, or caller-supplied header maps.
Samples either consume the same opaque port or remain compile-isolated fixtures
with zero Release link/reachability and non-authoritative test keys.

W2 seals production reads, writes, export, and restore of legacy psychological
state while retaining a migration-only reader. Only a preference with explicit
user confirmation, source, purpose, consent, and currentness may become a new
candidate. Emotional trend, frustration, cognitive-load inference, and
complexity-addiction inference do not migrate into durable identity. Legacy
content is erased or quarantined under the existing erasure owner, with a
content-free result expressed through the incumbent retention/erasure
disposition receipt rather than a new migration-receipt family. The
migration-only reader is package-private, capability-gated, one-shot,
deadline-bound, and has zero Provider, export, learning, or ordinary runtime
reachability.

Before any legacy UserState row is inspected for migration, W2 advances the
same privacy/deletion fence and opens it only through a scoped migration
capability. W0 freezes a closed physical encoding tag/presence matrix:

- `plaintextV0` requires the predecessor `payload_json`/Rust/routed bytes and
  forbids an envelope/key reference. After the fence, one package-private one-
  shot reader may copy one bounded source page directly into a non-escaping
  zeroizing buffer. It creates no temporary file, backup, Provider/export input,
  log, or second plaintext row. In the same bounded migration operation it
  either constructs and reopens an admitted encrypted v2 successor or records
  quarantine/erasure; and
- `envelopeV1` requires an exact envelope, custody/key generation, scope, and
  erasure-domain binding and decrypts only through the authorized custody
  lease. It forbids a raw `payload_json` fallback.

Unknown tags, tag/physical-row disagreement, both encodings present, or neither
present fail closed. Each row/encoding path has an exact content-free
migration/disposition receipt and crash-recoverable semantic key. Plaintext
`payload_json`, WAL/SHM frames, routed/Rust copies, caller-selected store URLs,
and backups are inventoried and acknowledged separately; a copied plaintextV0
row is never described as “envelope decrypted.” Production builders cannot
construct a raw SQLite UserState store. Erasure includes SQL row removal, WAL/
SHM checkpoint/rotation, backup acknowledgement, key destruction where a key
exists, and buffer zeroization; `secure_delete` without an actual governed
delete operation is not evidence.

The W2 atomic path manifest includes `BASUserState.swift`,
`BASUserStateStore.swift`, `BASRoutedUserStateStore.swift`,
`Cargo/bas-l8-engine/src/user_state.rs`, `BASCognitiveOSBuilder.swift`,
`BASCognitiveOSBundle.swift`, `BASCognitiveOSConvenience.swift`,
`BASTrainingDataExporter.swift`, all schema/SQL/WAL/backup fixtures, generators,
and the machine-derived reader/writer/export/restore test inventory. Removing
only the default builder while leaving a public raw store/export mouth is not a
migration.

`BASTrainingDataExporter` is also package-private migration/test machinery until
it is either retired or invoked only behind the admitted DatasetManifest and
the generic W5 egress state machine. There is no default `.all`, caller-owned
redaction, arbitrary destination URL, plaintext temporary file, or export of
full `BASUserState` before/after snapshots. An allowed export binds minimized
typed fields, source head/root, exact row count, consent/privacy/deletion epochs,
encrypted destination custody, external-copy lineage, and delete/query receipts.

Pagination over a canonical Session source uses
`(stableSourceID, sessionID, sourceLocalSequence, eventID, predecessorHash)` and
never advances wall time to escape a large equal-timestamp cluster. A
multi-source export uses only the verified canonical topological serialization
described in bundle A. If the source cannot provide a lossless chain/partial-
order proof, export returns a typed `coverageDeficit`/unavailable result and
cannot feed training, evaluation, or certification. Written/filtered counts
without a provable source-root row-count equality are not completeness evidence.

W3 produces HumanFit from authorized current evidence and consumes it only in
the sole context compiler and bounded presentation. Identity and style never
collapse into one fallback: missing or expired authorized identity yields
`guestOrUnknown`; missing or conflicting HumanFit evidence yields neutral
presentation without changing authenticated identity; missing persona-source
evidence yields neutral persona; and an expired emotion/habit hypothesis is
dropped without changing a confirmed preference. The controlled precedence is
authenticated identity, explicit confirmed preference, current scoped
HumanFit presentation evidence, bounded persona style, then neutral fallback.
Source gates reject every route from this transient value into truth, risk,
Provider routing, tools, effects, reward, learning, or durable identity.

W4 atomically updates the Organ request and every concrete adapter to remove
free-form persona strings and refs from Provider instructions. The new
structured presentation path and the legacy sink cannot coexist in production.

Cold-restart roster/persona/warrant snapshots are inert evidence only. Restart
reopens current K3/K4 role, grant, epoch, expiry, and revocation receipts before
constructing any executable Agent; `currentNanos = 0`, nonempty warrant ID, or
serialized commit/write fields never reconstitute capability. The Agent
registry accepts only owner-factory results and exposes no public registration
path that can upgrade a caller DTO into a writer.

W5 permits explicit, bounded public-or-fictional persona research only through
the admitted web effect. It yields untrusted source Artifacts for a later
Attempt and cannot modify the current persona or facts.

W6 embeds the two W0 manifest digests and verified dispositions as contained
values in the architecture replay manifest. It proves every legacy source,
sink, reinjection, export, comparison, and restore path is migrated,
decode-only, fixture-only, or Release-unreachable. Neither is a new top-level
manifest family.

The Waves author and admit this migration in sequence, but production does not
cut over it piecemeal. W2–W3 expose deterministic neutral fallback only; W3
structured presentation cannot reach a Provider until W4 removes every old
sink. One incumbent `production.cutover` receipt makes the complete bundle
Release-visible only after W6 reachability proof. No shipping closure contains
both legacy and replacement paths.

## Atomic migration bundle C: immutable App-Agent sharing

The existing `immutableShareLineageArtifactID` becomes a real governed
coordinate without adding an eighth App-Agent top-level payload. It references
the incumbent `BASCapabilityGrant` Artifact itself. That existing governed
grant gains one strict contained, self-ID-free `BASImmutableShareScope` whose
schema binds source and destination App-Agent roots/currentness, a preexisting
source-owned body Artifact/typed content commitment, a public field-mask digest,
purpose/expiry, and
consent, policy, sharing, deletion, and revocation epochs.
The grant field is exactly
`immutableShareScope: BASImmutableShareScope?`. A non-share grant requires
`nil`; a share grant requires a fully valid non-`nil` scope, and attenuation may
only narrow fields, purpose, duration, or destination rights. A historical
grant with `nil` may be reopened for its original purpose but can never
authorize a share. Because production W1 is still unadmitted, Task 2 freezes
this key in the first admitted wire; if external evidence shows that the
earlier exact version was already admitted, the candidate must fail closed and
use an explicit schema successor with backward/current/future fixtures rather
than silently add a key under the same version. No new registry row is added.

The acyclic sequence is:

1. construct a self-ID-free grant request carrying the share scope and typed
   request content commitment;
2. call the sole incumbent `issueCapability`, which canonicalizes and
   ordinary-puts the grant/attestation itself and returns the grant Store
   receipt; the caller performs zero separate put;
3. use `receipt.body.artifactID` as the immutable-share lineage coordinate;
4. for each exact source subject, call the incumbent `reserveCapability`, then
   `claimCapability` under the same grant/scope/currentness;
5. on a lost claim reply, call `lookupCapabilityUseReceipt` and never create a
   replacement use; and
6. W3 reopens the use receipt and materializes a transient read-only
   projection.

There is no separate creation reservation, share payload, share schema row,
share head, ACL Store, or share registry. The exact seven App-Agent top-level
payload cardinality remains unchanged. Share restrictions are not
caller-controlled booleans: the K4 rights set, authorized reader, field/purpose
validator, and learning/export/cache source gates permit only the closed
read-projection right and reject write, learn, cache, export, reshare, cutover,
or authority transfer.

Every W3 authorized read reopens the lineage grant, source, destination,
current epochs, and source retention before materialization, then consumes the
bounded fields through one package-private epoch-bound borrowed-reader
operation. It does not return an escaping plaintext DTO, public `Data`, cache,
or reusable projection. The same K3 snapshot/use receipt is rechecked before
the final field copy/consumer boundary; the temporary erasure-domain buffer is
zeroized at operation end. A later access always requires a new reserve/claim.

A share cannot extend source retention and never creates a destination-owned
content copy. Any persisted derivative would have to reuse the source
retention/erasure lineage and receive separate authority, so the default path
forbids it. An epoch change synchronously fences all future access and retained
Qinao buffers; it cannot retroactively erase bytes already lawfully perceived
by a user. Shared content is destination-learning-ineligible and cannot be
laundered through HumanFit or a conversation transcript.

## Atomic migration bundle D: physical capability and degradation

### Model-neutral package boundary

The final no-model claim must use a checked-in physical package boundary, not
only a runner-generated projection.

After legal source admission, Task 2 derives and freezes a complete predecessor
source/target/product/test/resource inventory in the non-runtime-authoritative
`docs/superpowers/evidence/qinao-w0-physical-package-closure-v1.json`. Task 2
binds that file's external SHA/length and predecessor source root. Its closed
schema lists, for each physical root, exact local package/product edges, exact
external package identity/revision/product edges, separate production/test
scope, module names, sources/resources, required reachable mechanisms, forbidden
symbols, and disposition. It is generated from the admitted predecessor plus
this fixed adjacency—not from the W4 candidate. W0 reopens the externally bound
file, proves its complete bidirectional census against the admitted predecessor,
and carries the unchanged root into the Wave evidence. W4 may only reopen
equality and then performs one atomic seven-root package migration:

- `BehavioralAISubstrate/Package.swift` becomes the BAS model-neutral core and
  declares no learned/model/provider package dependency;
- new `BehavioralAIAppleIO/Package.swift` owns non-learned typed Apple platform I/O
  leaves such as EventKit, CloudKit, notifications, CoreSpotlight read/mutation,
  BGTask, and App-Intent effect adapters. It has no Vision/Sound/Speech/Natural-
  Language/FoundationModels/model/learned/provider dependency;
- new `BehavioralAINonLanguageAdapters/Package.swift` owns learned mechanisms
  that perform no natural-language inference, interpretation, or tokenization
  and declares no language,
  generation, PCC, MLX, Hugging Face, or Transformers dependency;
- new `BehavioralAILanguageAdapters/Package.swift` owns text classification,
  Granite embedding, KaLM reranking, and their signed CoreAI/CoreML resources,
  with no generative/PCC/Chat/MLX/Hugging Face dependency;
- new `BehavioralAIGenerativeAdapters/Package.swift` owns Qwen/MiniCPM,
  CoreAI/MLX generation, ChatCompletions, PCC, and their external generative
  dependencies;
- `QinaoRuntimeSDK/Package.swift` becomes the Qinao model-neutral SDK and
  depends only on the BAS core; and
- new `QinaoProviderRuntime/Package.swift` owns Qinao concrete-provider
  compatibility products, provider samples, tests, executables, and the
  migrated contents of the current provider-dependent `SampleHost` package.

Each root has a closed package-dependency allowlist. Merely selecting one
product from a manifest containing a forbidden package does not count as
isolation. W1–W3 continue to compile the admitted predecessor graph. The W4 candidate
moves manifests, sources, tests, fixtures, resources, SampleHost surfaces, and
consumer imports together; no intermediate shipping graph is valid. Existing
product/module names may be exposed only by the adapter/provider roots as
temporary compatibility products. A name is never duplicated across roots,
and no compatibility product re-exports an adapter back into either core.
`BASJournalCLI` and every adapter-dependent test move to the appropriate
adapter/provider side. HostKit remains in the BAS core and imports only
model-neutral protocols.

The mixed incumbent lifecycle targets are split in that same W4 candidate.
Framework-neutral lifecycle-opportunity DTOs and ports move to a BAS-core
`BASLifecycleContracts` target. `BASHostKit` imports that target and stops
depending on or re-exporting `BASAppleLifecycleKit`. Concrete SwiftData/Apple
lifecycle and `AppleBGTaskSchedulerBridge` sources move to AppleIO; CoreML/
Chenglu/model sources move to the matching model-adapter root. Any temporary
`BASAppleLifecycleKit` compatibility module is owned only by AppleIO and cannot
be imported or re-exported by core. No same-named module straddles packages.

The incumbent `BASAppleEdgeWiring` module is not reused for the new effect leaf:
in HEAD it owns the learned CoreML Chenglu builder and no
`BASToolEffectAdapter`. Its module/product, source, consumers, and tests move
together to GenerativeAdapters unless the W0 inventory proves a narrower model
role. W4 instead creates one unique `BASTypedAppleIO` module with only the
structurally migrated, behavior-disabled Apple I/O leaves and zero semantic
effect caller. W5 creates the planned first `BASToolEffectAdapter` inside that
already admitted module at
`BehavioralAIAppleIO/Sources/BASTypedAppleIO/BASToolEffectAdapter.swift`.
Task 2 replaces the predecessor planned path; there is neither a duplicate
`BASAppleEdgeWiring` module nor a fabricated move of a file absent from HEAD.

The local adjacency matrix is exact, not candidate-derived:

- BAS core → no local package;
- AppleIO, NonLanguageAdapters, LanguageAdapters, and GenerativeAdapters → BAS
  core only; peer-adapter edges are forbidden;
- QinaoRuntimeSDK → BAS core only; and
- QinaoProviderRuntime → QinaoRuntimeSDK, BAS core, AppleIO, and the three model
  adapter roots.

The Task-2-frozen, W0-verified evidence file supplies the exact predecessor-fixed external package/
product allowlist for every root, including production and test scope. Test
targets obey the same direction and cannot import a forbidden dependency merely
because production code does not. The normalized candidate DAG must equal both
this local adjacency matrix and that externally bound file; a digest generated
only from the candidate is not proof.

AppleIO canonicalizes deterministic request identities and state transitions;
it never claims external Apple outcomes are deterministic. Text, titles,
barcodes, and notification payloads may pass as opaque untrusted structured
human/tool data through AppleIO or NonLanguageAdapters, but those roots cannot
interpret, tokenize, embed, classify, rerank, or generate natural language.

The sole composition authority remains the already planned canonical
`BASCoreAIRosterComposition`, but Task 2 moves its model-neutral contract/factory
to `BehavioralAISubstrate/Sources/BASHostKit/BASCoreAIRosterComposition.swift`.
The concrete Apple effect leaf is the one new `BASTypedAppleIO` module/path
defined above; it does not inherit the incumbent learned edge-wiring identity.
This design does not introduce `BASProfileComposition` or a second seam. The
atomic split versions that factory in place: its BAS-core form is
model-neutral, accepts an explicit closed tuple of already constructed
protocol factories, and performs no self-registration or package discovery.
Concrete CoreML/CoreAI/model builders move to their adapter roots and are
passed in; the predecessor concrete form and successor protocol-only form
never coexist as two composition factories.

The “closed tuple” is one core-owned fixed `BASModelRosterBinding` with exactly
five named role slots: Qwen generation, MiniCPM generation, Granite embedding,
KaLM reranking, and PCC remote generation. Each slot is a role-specific strict
availability value: `.available(any RoleProtocolFactory)` or
`.typedUnavailable(reason, evidence)`. There is no optional array, omitted
slot, generic tensor factory, peer-adapter type, or self-registration. Every
profile bootstrap constructs all five slots, so a lower profile compiles
without importing the unavailable adapter and the composition still proves
exact role cardinality and bijection.

The learned language classifier is deliberately not a sixth model-roster role.
The same sole `BASCoreAIRosterComposition` input also has one fixed, core-owned
`BASLanguageClassifierCapabilityBinding`, whose only cases are
`.available(any BASLanguageClassifierFactory)` and
`.typedUnavailable(reason, evidence)`. Every bootstrap supplies both the exact
five-slot model binding and this exact classifier binding in the same factory
call. `full` and `noGenerative` supply the admitted classifier factory;
`noLanguage`, `noLearned`, and `QinaoPlatformNeutral` supply typed unavailable.
The composition routes an available classifier to the real context-classifier
consumer. Adapter self-registration, a second composition seam, an optional
classifier, or disguising it as the Granite slot is forbidden.

`Profiles/QinaoNoLearned`, `Profiles/QinaoNoLanguage`,
`Profiles/QinaoNoGenerative`, and `Profiles/QinaoFull` are four checked-in
SwiftPM profile harness roots, not four additional production component roots.
Each directory contains a `Package.swift` that declares only its allowlisted
local packages/products, one bootstrap target whose Swift source calls the
same `BASCoreAIRosterComposition` factory, and one nonempty test target. A
manifest never imports or calls runtime Swift. A Release selects exactly one
profile harness and one bootstrap factory call; adapter roots cannot register
themselves or create another composition seam.

Each profile also has a predecessor-fixed `requiredReachableMechanismRows`
equality in the W0 physical-closure evidence. A dependency or typed-unavailable
slot is not positive reachability. `noLearned` executes real deterministic
rule/search, human/tool, read/effect, Work/Automation, and recovery consumers;
`noLanguage` additionally executes every admitted non-language learned use case;
`noGenerative` executes the classifier through the same composition input and
real classifier consumer, plus Granite embedding and KaLM reranking through
their real protocol consumers; and `full` executes the admitted Qwen and
MiniCPM chains while PCC remains independently available or typed unavailable.
Every required row has one nonempty behavior test and a composition-to-consumer
callgraph proof. Forbidden-zero scans and positive reachability are both
required; neither substitutes for the other.

`Profiles/QinaoPlatformNeutral` is one additional checked-in physical
cross-check harness, not a fifth semantic runtime profile. It depends only on
BAS core and QinaoRuntimeSDK, constructs the same five role slots as typed
unavailable, actually runs Work/Automation/recovery, and proves zero Apple
capability-package/framework/object/link/resource/registration reachability.
The exact forbidden framework set is FoundationModels, CoreML, Metal, MetalKit,
MetalPerformanceShaders, MetalPerformanceShadersGraph, NaturalLanguage, Vision,
VisionKit, Speech, SoundAnalysis, Translation, CoreSpotlight, EventKit, CloudKit,
UserNotifications, BackgroundTasks, AppIntents, VisualIntelligence,
ImagePlayground, and SwiftData. Cross-platform Foundation, SQLite, the Swift
runtime, and a pinned portable cryptography product are separately allowlisted;
the phrase "zero Apple" never ambiguously forbids those foundations. It is the
physical proof for the no-Apple degradation contract; an iOS profile manifest
that resolves AppleIO cannot be reused to claim platform-neutral isolation.

The core package and its dedicated test target declare no MLX, Hugging Face,
Transformers, language-model, CoreAI/CoreML model-resource, or provider-adapter
dependency. Its source, target, package, object, link, resource, registration,
dynamic-loader, network, and test closure are scanned bidirectionally. A
nonempty test executes in that closure.

The checked-in profile-to-package/product closure is exact for the iOS Release
profiles:

- `noLearned` resolves BAS core, QinaoRuntimeSDK, and non-learned typed AppleIO,
  with all five model slots typed unavailable;
- `noLanguage` adds
  `BehavioralAINonLanguageAdapters`, and no mechanism in that adapter performs
  natural-language inference, interpretation, or tokenization;
- `noGenerative` adds `BehavioralAILanguageAdapters` for classification,
  Granite, and KaLM, but resolves no generation/PCC/Chat/MLX/Hugging Face node;
  and
- `full` adds `BehavioralAIGenerativeAdapters` and
  `QinaoProviderRuntime`.

These are physical product closures, not new semantic runtime profiles. Each
checked-in profile manifest proves both `swift package show-dependencies` and
the resolved graph, plus a normalized target-DAG digest, bidirectional source
and resource inventory, selected-test binary link map, forbidden-node-zero
scan, and nonempty exact test.

On a platform or Release configuration where AppleIO is absent, the same
semantic no-learned posture is built through `QinaoPlatformNeutral`, uses the
platform-neutral BAS effect/read protocols, and keeps every Apple capability
typed disabled; omission never changes model-role slots or creates a fifth
runtime profile.

Physical package roots and profile manifests are build-isolation mechanisms,
not logical owners, M rows, create permissions, Layers, kernels, rings, planes,
Agents, or composition authorities; all fixed architecture cardinalities stay
unchanged.

A signed hermetic projection may be retained as a transition and independent
cross-check. It does not by itself satisfy final model-neutral completion.

Runtime profiles remain:

- full Provider;
- no generative Provider;
- no language inference;
- no learned inference.

No fifth runtime profile is added. A stricter framework-erased packaging build
is a physical closure, not a semantic capability profile. The
no-language-framework closure forbids FoundationModels, MLX, Tokenizers,
Transformers/Hugging Face, language CoreAI resources, generation weights,
templates, tokenizers, ChatCompletions registration, and PCC symbols. The
no-learned-framework closure additionally forbids CoreML model resources,
NaturalLanguage embeddings, learned classifiers, and every learned-resource
loader. A semantic profile that merely imports an allowed platform type is not
misreported as framework-erased.

The current mixed paths receive explicit disposition in that W4 migration:

- `BASContextClassifierMLAdapter`, `BASCoreAIContextClassifierAdapter`, the
  RuntimeCore classifier source, and `BASContextClassifier.mlmodel/.aimodel`
  move to the language-classification package because they tokenize and
  interpret natural-language text; they are absent from `noLanguage`;
- HostKit retains only protocol injection and never imports the concrete
  classifier, lifecycle implementation, Metal substrate, or provider adapter;
- concrete `BASMetalSubstrate` moves to NonLanguageAdapters. An Apple hardware
  profile may load only signed precompiled `.metallib`; BAS core and
  `QinaoPlatformNeutral` contain only the model-neutral compute protocol and no
  Metal/MPS/CoreML object or link. `.metal` source compilation and
  `makeLibrary(source:)` move to a compile-isolated lab/build-tool path and are
  Release-unreachable;
- the public arbitrary-URL/function/tensor `BASCoreAIModelRunner` is retired.
  LanguageAdapters and GenerativeAdapters each own package-private, exact role/
  signed-asset/function allowlisted executors with no runtime peer-package edge;
  mechanically shared generated source does not create a public shared loader.
  `noGenerative` forbids generic runner public API, generation/session symbols,
  arbitrary model URL/function selection, and dynamic generative asset loading,
  not merely a package name; and
- every `MLModel.compileModel` call moves to the hermetic offline build/dev
  path; Release consumes only signed precompiled model artifacts.

The W0 disposition inventory is machine-derived and also closes
`BASMiniLMEmbeddingProvider`, `MiniLM.mlmodelc`, `vocab.txt`,
`BASCoreAINLIVerifier`, Qinao/BASJournal MiniLM constructors, Gemma/Llama/
Qwen2.5 registries, Apple Foundation positive peers, legacy MLX factories, and
every Qinao endpoint/sample/test that imports or constructs them. Each path is
migrated to the four-local-role subset of the fixed five-slot roster,
decode/fixture-only, or
Release-unreachable; no unlisted language mechanism survives as an implicit
fallback. A deterministic encoder retained in core must prove that it never
interprets free text in `noLanguage`.

### Closed model roster and PCC

Qwen3.5-4B, MiniCPM5-1B, Granite Embedding 311M Multilingual R2, KaLM Reranker
Nano, and PCC retain distinct roles. Absence is typed unavailable; no role
silently impersonates another. A manifest row is not callable until its full
role ABI is certified end to end:

- Qwen and MiniCPM bind exact asset/material/conversion digests, full-precision
  or quantization/group/scale identity, tokenizer/vocab digest, special-token
  IDs, prompt/template, maximum context, position/RoPE, attention mask,
  prefill, decode, KV axis/layout/stride/update semantics, sampler,
  deterministic seed/randomness policy, stop, output schema, tensor
  name/shape/dtype, numerical tolerance, cross-device golden vectors, and
  accepted-prefix behavior;
- Granite binds exact asset/conversion/quantization identity, tokenizer/vocab
  and special-token IDs, padding/attention mask, input tensor contract,
  pooling, normalization, output dimension, dtype, truncation,
  vector-distance convention, numerical tolerance, and golden embeddings;
- KaLM binds exact asset/conversion/quantization identity, pair encoding,
  vocab/special-token IDs, padding/attention mask, truncation, input tensor
  contract, score direction, calibration, tie/order semantics, rerank limits,
  numerical tolerance, and golden ranked fixtures; and
- each role proves manifest → signed asset → concrete protocol adapter → sole
  composition → nonempty consumer, with no generic tensor runner masquerading
  as a complete model implementation.

Local CoreAI assets require offline AOT conversion and that complete ABI
certification before one external composition point may select them.

PCC remains optional remote Provider execution. W0 pins the installed SDK and
classifies the exact model constructor and every availability, quota,
`contextSize`, language/locale, capability, prewarm, session, and respond API as
`provenLocalNonStart` or `possibleStart`; async/throwing or unknown behavior is
`possibleStart` until independent evidence proves otherwise. W4 freezes the
remote-opaque descriptor/schema and consumes only previously admitted static
capability evidence; it constructs zero PCC model, session, or request.

W5 first freezes the stable Attempt, commits K3 pending state, reopens the
necessary K4 use, and seals/reopens the exact PCC request as the closed
`remoteProvider` operation kind in the sole
`effect.zone-c-saga`/`BASEffectBrokerSQLiteStorage` journal. The K3 actor obtains
and verifies the ordinary protocol's
authenticated transaction-external outbox snapshot, then binds only its
content-free row/proof identity and commits
`possibleStartCommitted` before the earliest API classified `possibleStart`—
which may be the model constructor or a fact getter—and never assumes a getter
is local merely because it looks descriptive. It
constructs exactly one Attempt-private
`PrivateCloudComputeLanguageModel()` and reads availability, quota, context,
locale, and capability facts from that exact instance. Any fact absent from the
installed API is typed unsupported rather than guessed. A failed check produces
zero session and zero respond calls. Only a passing check may construct exactly
one Attempt-private `LanguageModelSession(model:)` from the same model instance
and cross one physical respond boundary. It never uses an omitted/default
`SystemLanguageModel` initializer, reconstructs the model after commitment, or
mixes facts from another instance. Before the independent W6 device cutover,
the W5 production call graph remains Release-unreachable.

If a failure occurs after respond may have started, Qinao uses an official
terminal-query API only if one is actually available and certified. When PCC
offers no such query, the result is typed query-unsupported/indeterminate; it
never resends, swaps model, clears the Attempt, or creates a second session.
Only the authorized request, accepted user-visible output/chunks, accounting,
and owner receipts may become app recovery evidence. A reasoning/progress
segment remains `neverPersist` even when the framework exposes it in a session
transcript; it is not conversation truth, memory, learning data, or a
SolutionArtifact.
The default concurrent PCC resource policy is one; an experimental maximum of
two requires independent device evidence and is a Qinao policy, not an Apple
API guarantee. W6 device evidence is required before cutover.

Both `PrivateCloudComputeLanguageModel.Executor.prewarm(model:transcript:)` and
`LanguageModelSession.prewarm(promptPrefix:)` are explicit possible-start
inventory entries. Production call count is zero unless the installed SDK and
device evidence prove a classified use; if admitted, the earliest prewarm is
the possible-start boundary and occurs only after the same Attempt pending/K4/
sealed-outbox/`possibleStartCommitted` sequence. It never becomes an
unjournaled optimization. The initial closed
posture is W4 prewarm/model/session/respond count `0`, W5 model count `1` and
prewarm count `0` per Attempt, and W6 model count `1`/prewarm count `0` under a
separate bounded certification operation. W6 facts never authorize or stand in
for a W5 Attempt.

### Apple capabilities

Every Apple capability has an explicit inventory row containing owner, exact
symbol and path, target/configuration, API availability, entitlement or proven
none, device/OS, privacy/disclosure, recovery behavior, cutover evidence, and
status. Framework availability alone never enables a capability.

Perception and speech are untrusted ingress. Reads use the existing read
gateway. Semantic external mutations use K3/K4 and the existing Zone-C effect
path. Background lifecycle opportunities and foreground permission gestures
retain their separate, typed leaves. No Apple framework becomes an Agent or
state authority.

The minimum closed inventory distinguishes Vision/VisionKit, Speech,
SoundAnalysis, NaturalLanguage/Translation, CoreSpotlight query, CoreSpotlight
index/delete, notifications, CloudKit, App Intents, and each additional Apple
surface separately. Vision, speech, sound, translation, and annotation enter
only typed untrusted ingress/preprocessing. CoreSpotlight query uses the read
gateway. EventKit mutation, notification schedule/remove, CloudKit
write/delete/subscription, and CoreSpotlight index/delete use the incumbent
`effect.zone-c-saga`/`BASEffectBroker` owner through the planned first and sole
`BASTypedAppleIO/BASToolEffectAdapter` physical leaf; that file is not
misreported as present in HEAD. Availability or an import never bypasses the
immutable handler-map digest, signed Release binding, K3/K4, privacy,
possible-start, and recovery proof.

The background split follows the Wave dependency direction. W0 inventories both
incumbent paths. W4 atomically moves `AppleBGTaskSchedulerBridge` into AppleIO,
moves its framework-neutral port/DTO into BAS core, and changes
`QinaoBGMaintenanceBridge` plus `QinaoLifecycle` into model-neutral injection/
request facades or retires them, with zero `BGTaskScheduler` symbol/link
reachability. All behavior remains disabled during this structural migration.
W5 extends only the already planned `effect.zone-c-saga` journal with the closed
`appleLifecycleOpportunity` operation kind and generic possible-start seam; it
does not create a lifecycle journal or owner. W6 alone implements, certifies,
enables, and cuts over the Apple API behavior. At every
first-compilable cut exactly one physical Apple background adapter remains.
Inventory rows split CloudKit
read/write/subscription, notification status/schedule/remove, BGTask
register/submit/cancel, and App Intent ingress/effect. A source/callgraph gate
enforces an exact per-class allowlist: `BGTaskScheduler` register/submit/cancel
may occur only in the sole `AppleBGTaskSchedulerBridge` lifecycle-opportunity
leaves; notification permission may occur only in the explicit foreground
user-gesture leaf; reads may occur only through the read gateway; and the
listed semantic mutations may occur only through `BASToolEffectAdapter`.
Every call outside its classified leaf fails. The gate never forces
BackgroundTasks or permission UI through a universal Zone-C handler.

Physical placement follows exact symbols and use cases, not framework names.
The BAS core contains only framework-neutral ingress/read/effect DTOs and
protocols. Non-learned typed EventKit/CloudKit/notification/CoreSpotlight/
BGTask/App-Intent I/O lives in `BehavioralAIAppleIO`; only request
canonicalization and its state machine are deterministic, never the external
outcome. Vision/VisionKit object,
barcode, geometry, and other proven non-text perception plus non-language
SoundAnalysis live in `BehavioralAINonLanguageAdapters`. OCR, text recognition,
`DataScanner`/`ImageAnalyzer` text, Speech, NaturalLanguage, and Translation
live in `BehavioralAILanguageAdapters`. FoundationModels/PCC and other
generative Apple mechanisms live in `BehavioralAIGenerativeAdapters`. Each root
has exact allowed and forbidden symbol/use-case lists; a generic Vision or
VisionKit umbrella wrapper cannot cross both roots. W6 cannot recreate a
framework-aggregating `AppleSurfaceIngressAdapter` inside BAS core after W4 has
proved noLearned/noLanguage isolation.

`VisualIntelligence` and `ImagePlayground` receive distinct closed inventory
rows rather than inheriting the Vision row. Their initial status is disabled
with zero source/object/link/resource/Intent-delegation reachability in every
Release profile, including `full`. A future separately admitted row may enable
only its exact typed profile/edge. A visual-ingress permission never
authorizes system-model delegation, image generation, Provider execution, or
external mutation.

The incumbent `BASNLEmbeddingProvider` remains lab-only/retired and
Release-unreachable unless independently certified for the same role; it is
never an implicit fallback for Granite. Capabilities without exact target,
entitlement-or-proven-none, device, privacy, recovery, and cutover evidence
remain typed disabled. There is no aggregate “all Apple enabled” switch.

### AOT boundary

Release closures contain no app-supplied source JIT, dynamic-library
generation, or unclassified dynamic executable generation. Apple platform
graph specialization is a separately classified platform mechanism. AOT
evidence uses three non-interchangeable classes:

- `observableOutput` binds exact signed input, tool/API/toolchain identity,
  deterministic typed output content commitment, output location, and verification; and
- `platformOpaqueSpecialization` binds signed input, API invocation, OS/build,
  entitlement/device evidence, observed or typed-unobservable cache
  location/behavior, and proof
  that app-source JIT is Release-unreachable, without claiming exactNative
  cache bytes that the platform does not expose; and
- `platformOpaqueGraphSpecialization` permits a Release
  `MPSGraph.compile`/`MPSGraphExecutable` path only when it binds the canonical
  graph, shape, dtype/config digest, API and OS/build identity, uses no source
  string or dynamic library, keeps the process-local executable cache opaque
  and nonpersistent, and is absent from framework-erased profiles.

`makeLibrary(source:)` and `MLModel.compileModel` remain lab/offline build
mechanisms and are absent from Release call graphs. Apple-managed
specialization of already signed data is never conflated with app-controlled
JIT or with a Qinao-owned exactNative checkpoint. `MPSGraphExecutable` is
never a checkpoint, Artifact payload, portable-archive body, or recovery truth.

### Protected Python rotation

All authority-bearing commands use stable-opened, digest-bound absolute tool
descriptors. Bare `python3`, `python3.14`, `swift`, `cargo`, or `xcodebuild` is
forbidden outside explicitly marked non-authoritative development/CI blocks.

Digesting one file descriptor and later executing the same pathname is not
identity binding. The child executes the verified object itself when the
platform supports fd-based execution; otherwise the controller first copies it
into private no-write/no-symlink immutable custody, fsyncs and stable-opens that
copy, then executes only that sealed path. Before K3
`possibleStartCommitted`, verification is strictly static: sealed object/fd,
signature/code identity, loader, dylib/framework, standard-library/module/
plugin, SDK, and transitive child-tool closure. No child, launcher, interpreter,
or helper has started, and an injected first-instruction marker remains absent.

Only after K3 `possibleStartCommitted` may the protected-tool owner durably
claim one handoff and start the exact sealed object. A child-start attestation
is a post-start observed receipt, never a pre-start authorization. When target
code must be held before its first external side effect, the admitted minimal
sealed launcher starts only after that COMMIT and blocks the target behind its
already verified gate until image/loader attestation succeeds. Attestation
failure kills/quarantines the same operation and remains failure or
indeterminate; it cannot authorize a second spawn. Post-execution path recheck
is diagnostic only and can never retroactively authorize an already started
foreign image.

Python 3.14.5 becomes protected only through the incumbent protected-tool
owner's atomic predecessor runtime-profile rotation, completed in Tasks 0–2
before the first Wave that uses 3.14. The currently admitted 3.9.6 profile
verifies the successor package and external admission evidence; 3.14 never
self-authorizes. The signed row binds executable bytes, code identity, complete
standard-library/runtime root, platform, ABI, version, required modules,
sterile environment, Swift/SDK/toolchain root where relevant, plugins,
transitive child-process descriptors, exec-trace policy, predecessor profile,
and test vectors. One operation uses either the old or new active profile,
never a mixture. The old 3.9.6 profile becomes historical-verify-only after
rotation; rollback requires an authorized profile CAS and receipt rather than
ambient fallback.

### Performance

Cold-40 and sustained-30 remain optional, dual-device, shipping-identity-bound
claims. Failure disables only the claim. A performance candidate whose sealed
durability, privacy, causal, replay, K3/K4, retention, grounding, or quality
fields differ from the correctness candidate is ineligible regardless of
throughput.

A contained `BASCorrectnessInvariantProjection` canonically compares the
authority/configuration roots, retention and erasure posture, privacy/egress,
causal/replay policy, recovery coverage, output quality, grounding, and safety
identity. Its normalization schema is a closed path-exact allowlist. Unknown or
new fields are included and fail equality until explicitly admitted. Only
listed trial-local IDs, device observation IDs, clocks, and nonces may be
normalized; evidence Artifact IDs are never ignored as a class. The projection
compares each evidence role and typed content commitment while allowing substitution only
for an explicitly listed trial-local wrapper identity. A performance candidate
must reference the same correctness-manifest digest and may append one separate
performance-evidence subtree; it cannot reseal a weaker correctness projection.

## Atomic migration bundle E: learning, biomimetic inspiration, and longevity

### Governed learning

Learning remains a delayed candidate path. Current Main output cannot modify
the current App Agent. A candidate binds the source App-Agent root, terminal
Attempt, seven cleaning-gate receipts, independent outcome/causal evidence,
prior orthogonal head/Self, deletion and consent currentness, and explicit
ineligibility of shared read-only data. A fresh Attempt sees a successor only
after L13/K3/L14/K4 and certification/cutover.

Legacy `BASUserState` and direct training exporters cannot bypass the governed
DatasetManifest, eligibility, minimization, deletion, split, OPE/shadow/canary,
rollback, and egress-receipt chain.

SFT, DPO, IPO, ORPO, KTO, RLVR, GRPO, and contextual-bandit work remain typed
evidence shapes under the incumbent DatasetManifest/TrainingJob/certification
owners, not separate learning authorities. An external trainer may compute a
candidate gradient or artifact; it cannot sign eligibility, certify a policy,
advance Self/App-Agent heads, or cut over a result. Ordinary dialogue,
HumanFit, immutable-share content, and recovery-only cache material never
become training data merely because they were retained.

### Biomimetic crosswalk

The neuroscience terms below are offline explanatory aliases only. They add no
runtime field, score, trigger, scheduler input, allocation rule, or authority.
Only independently authorized incumbent evidence and receipts may drive the
existing mechanisms.

- Prediction residual and surprise map to existing L4/L6/L7/L10 observations.
- Free-energy language is a heuristic under fixed truth, risk, resource, and
  authority constraints. No opaque scalar may rank or authorize the system.
- Precision and neuromodulation are interpretations of already-authorized risk
  or resource evidence. That incumbent evidence may tighten the K1 ceiling or
  SSM `observationShadow` under its existing rules; the research label itself
  cannot change the running Attempt.
- Default-mode inspiration maps to L9 output-null bounded counterfactual work
  and W3 sleep-like snapshot/candidate generation only when an incumbent
  scheduler/budget/Attempt receipt has already authorized that work. The label
  cannot allocate it and has no direct memory, persona, policy, route, effect,
  or state write.
- Grokking is a research-only observation of delayed generalization on frozen
  candidates using independently held-out, temporal, OOD, and all-clean-
  ancestor replay. It is not a training objective, reward truth, guaranteed
  property, or automatic promotion signal.
- MorphoHDL may have an isolated non-Release lab compiler and simulator. Its
  output is an untrusted bounded successor proposal for a future Attempt; it
  must enter through the incumbent untrusted-proposal ingress and cannot
  ordinary-put an authoritative Mission graph or perform its root CAS.
  Production/runtime/package/link/resource/archive closures contain zero
  MorphoHDL compiler, dependency, registry, Agent, effect, or adoption
  authority.

### Portable replay and archival recovery

The planned W6 first-wire `BASArchitectureReplayManifest`, owned by
`runtime.replay-manifest`, gains one strict contained
`BASPortableArchiveEnvelope`; neither is misreported as production-present in
HEAD, and there is no additional top-level archive payload or second archive
Store. The W1/W2/W6 placement is the one frozen in bundle A: W1 declares the
model-neutral contained cut/lane/page/MMR values, the planned W2 K3 archive-
operation row performs persistence and short transactions, and W6 alone defines
the first-wire manifest codec. No row or implementation is called “existing”
when it is absent from the active plan or production HEAD.

Archive capture is a causal vector cut, never a claimed cross-database
transaction. First, one short W2 K3 transaction commits
`archiveCutPreparing`, freezes the predecessor conversation/Mission/currentness
roots, authenticated K3/Event root/high-water mark and epoch vector, and the
root/count of every K3 Artifact/boundary dependency at that cut. It also binds
one non-caller-selectable `archiveSourceUniverseID` and its current scalar
`archiveSourceUniverseEpoch`. One archive belongs to exactly one predeclared
Workspace/user erasure universe; a cross-universe request is split into
independently authorized roots or is typed unavailable. It pins those
facts against cleanup under the stable archive operation ID. Only after that
K3 cut exists does the coordinator capture promoted authenticated snapshots of
every external lane: Event sources when physically separate, the Artifact
outer-anchor generation plus separate identity-record,
`artifact_put_claim_binding`, and custody-generation root/count/high-water
marks, and each closed `BASBoundaryOwnerID` journal's owner/store incarnation,
anchor generation, root/count/high-water mark, and canonical cursor.

Paginated causal-coverage proof then establishes that every Artifact, claim
binding, selected custody generation, sealed row, claim, outcome, or receipt
referenced by the frozen K3 cut is a member of the corresponding captured lane.
Every included owner row proves its K3 predecessor is at or before the cut.
Rows whose predecessor is after the cut receive the canonical `postCut`
exclusion with membership proof; a post-cut claim/outcome for an operation
already in the cut is a typed `causalExtension` and may be included only as
reconcile evidence, never as a silently advanced K3 head. Missing required
dependencies, unbound orphans without an explicit disposition, and a K3 fact
newer than its Artifact/owner proof fail. A final short K3 transaction verifies
only its own cut revision and the completed proof roots/counts, then seals one
authenticated, self-ID-free `BASPortableArchiveSourceSnapshot` body and its
K3 row/root/rollback-anchor proof. No K3 transaction reads another database or
awaits an owner.

That canonical snapshot body binds the exact predecessor roots, all lane
roots/counts/high-water marks/cursors, schema/registry root, deletion/privacy
epochs, canonical inclusion-policy revision, causal-coverage root, and exact
archive operation identity. It explicitly excludes the enclosing root
manifest, all chunks and rows created by this archive operation, its current
admission/operation/export receipts and outbox, and source rows after the
frozen cut. The exclusion set is typed by operation ID and row kind, not a
caller filter. The final root envelope embeds byte-equal canonical snapshot
bytes plus the after-freeze K3 membership/anchor proof, so an independent
decoder can recompute the snapshot root after the original databases are gone.
The snapshot body excludes its own row/root/proof fields; its proof is computed
after the body root and cannot feed back into it. A bare opaque snapshot root,
missing Artifact sub-lane, missing owner lane, or foreign proof is invalid.

The existing K3 currentness vector owns the conservative
`archiveSourceUniverseEpoch`; it is not an archive head, Store, owner, or
per-archive mutable row. Every deletion, consent/privacy withdrawal,
revocation, taint, or erasure-key retirement that can affect any source in that
fixed universe advances the scalar in the same K3 transaction as its ordinary
fence. Chunk admission, root adoption, authorized custody read, head CAS,
export, share, and restore bind and recheck exact equality with the snapshot
epoch in O(1). An epoch mismatch leaves historical bytes independently
fixity-verifiable but makes the archive stale and unusable for read, export, or
restore until a lawful successor archive is captured. This deliberately
invalidates the universe conservatively rather than enumerating millions of
leaf scopes or weakening deletion. Mutation of a single source must therefore
fence a ten-million-leaf archive with one currentness comparison.

The one existing planned top-level manifest family is versioned with a strict
closed `chunk | root` role tag under the same codec, registry row, owner factory,
and Artifact/K3 authorities. It does not create a second payload family. A
bounded `.chunk` is an independent leaf—not an Artifact predecessor chain—and
contains source-snapshot ID/root, exact leaf index, one canonical contiguous
source-cursor interval, one canonical authenticated page-proof encoding,
ordered scan-outcome encodings, scanned/included/excluded row counts and roots,
per-exclusion-reason counts/roots, byte count, and a domain-
separated `entryIntervalCommitment`. The commitment preimage is exactly
`domain || sourceSnapshotRoot || leafIndex || startCursor || terminalCursor ||
pageProofCommitment || canonicalScanOutcomes || scannedCount || includedCount ||
excludedCount || reasonRoots || includedRoot || excludedRoot || byteCount`; it
excludes the commitment field, this chunk's future Artifact ID, admission/
operation receipts, structural certificate, MMR root, and future root manifest.
Ordinary Artifact identity then commits to the complete chunk payload. Nil/
default indices, empty noncanonical leaves, self/final-tag-inclusive
commitments, or equal identity/changed bytes are corruption.

Every physical source cursor in the interval contributes exactly one contained
`BASPortableArchiveScanOutcome`: `.included(BASPortableArchiveChunkEntry)` XOR
`.excluded(closedReason, typedSourceRowCommitment)`. Closed exclusion reasons
are policy-ineligible, privacy/deletion-excluded, device-bound-unexportable, or
unsupported-with-coverage-deficit, plus the causally proven `postCut` case;
unknown/caller-text reasons fail. An unsupported coverage deficit forces the
root's coverage posture to partial/unavailable and cannot certify a complete
archive. Thus
`scannedCount == includedCount + excludedCount`, and a policy-eligible omission
cannot hide by shortening the output list. Each included entry is one contained
strict `BASPortableArchiveChunkEntry` case:
`.event`, `.artifactIdentity`, `.artifactCustodyGeneration`,
`.artifactClaimBindingProof`, `.k3FactOrReceipt`, `.boundaryOwnerReceipt`,
`.tombstone`, `.externalCopyLineage`, `.schemaOrCodecDescriptor`,
`.payloadMediaToolOrModelDependency`, `.migrationOrCompensationReceipt`,
`.cryptographicSuiteOrKeyMigrationDescriptor`,
`.effectOrProviderReplayDisposition`, or `.rehydratorConformanceVector`. Every
case has a fixed presence matrix for source owner/lane, stable row identity/
revision, source cursor, typed content commitment and sealed bytes or content-
free proof, and source-root/HWM binding. Variable-cardinality schema, dependency,
migration, effect, and conformance inventories therefore live in bounded chunk
entries rather than making the root Artifact O(N). The frozen inclusion policy
lists the allowed tags and one canonical cross-lane total-order key. Unknown/
default/`Any`, a cross-tag field splice, free JSON, or a lane-order collision
fails in Swift and the independent decoder. These unions are contained in the
existing manifest codec and receive no registry row, owner, Store, or Artifact
kind.

Classification is evidence, not a scanner assertion. For each bounded interval
the K3 archive method—never a public caller—uses the exact source owner's
package-private page-preflight outside any K3 transaction to obtain an
unforgeable, non-Codable, invocation-local
`BASValidatedArchivePageSnapshot`. It proves membership of every contiguous row
under the frozen owner root/HWM, the canonical row bytes/typed commitments,
row count/root, and the unique included/excluded decision under the frozen
policy revision and epoch vector. Its portable canonical page proof is embedded
in the chunk; the invocation-local wrapper is not. If an incumbent lane lacks
bounded membership proofs, that same owner adds Merkle page implementation rows
under its existing authenticated root/anchor—not a new Store or head. K3 begins
only after preflight; inside SQL it rechecks its cut/operation/policy revision,
cryptographically verifies the page-proof digest, and registers only outcomes
computed by that proof. Eligible↔excluded relabeling, same-count substitution,
or a caller-authored privacy reason fails.

Local authentication and portable authentication are distinct. A lane whose
root/page proof is protected only by a keyed MAC can support same-device
recovery but can never certify the root as portable: exporting the MAC secret is
forbidden because it would grant proof-forging authority. For a
`portableComplete` posture, each incumbent lane owner creates, after the local
cut is fixed, one public-key-verifiable bridge attestation. Its signature binds
the owner/lane and store incarnation, local authenticated root and anchor
generation, archive operation and K3 cut, source-snapshot root, page-index
root/count/HWM, current algorithm suite, public verifier/certificate chain, and
algorithm/key-migration chain. It excludes the enclosing manifest ID/root and
all future receipt fields. The private signing key remains with the incumbent
owner or Secure Enclave custody; only the public verifier, certificate,
revocation, and migration chain travel in the existing descriptor chunk cases
and fixed root commitments. A MAC-only lane is strictly
`deviceBound | portableUnavailable`, and an independent decoder must report that
typed posture after the original database/Keychain/device is gone. Replacing or
exporting a MAC secret, verifier chain, anchor generation, bridge root, or page
index cannot turn it into a portable proof.

The planned W2 K3 archive-operation row owns one non-authoritative
`pendingArchiveAccumulator`, implemented as the same bounded
`pendingClosureBuild`/MMR machinery rather than a new head. It stores the source
snapshot root, expected next leaf index/cursor, a UInt64 leaf/row counter, one
portable-content MMR and one durable-dependency MMR with at most 64 peaks each,
cumulative scanned/included/excluded/byte counts and domain roots, per-lane
cursors, and indexed immutable leaf-membership rows. Before work begins it also
commits a finite trusted `archiveBuildRetentionLease` with generation,
`inactivityDeadline`, fixed renewal window, source-retention bound, spatial
row/byte quota, epoch vector, and cancel tombstone. Each chunk append in the
same short K3 transaction extends the group pin for the indexed members only
through that finite lease.

Renewal is an O(1) same-generation CAS and is legal only when the cursor,
portable-content MMR HWM, and durable-dependency MMR HWM have all advanced
strictly since the prior renewal and the source epoch, retention horizon, and
spatial quota remain current. It extends one finite inactivity window; it does
not impose a fixed total wall-clock maximum on a continuously progressing
user-durable archive. Stalled work expires and pages the whole group for
cleanup. A source with a finite retention horizon is admitted only when a
pre-scan proof over its frozen count/bytes and admitted worst-case throughput
shows completion can fit before that hard horizon; otherwise it fails typed
unavailable before creating chunks. No renewal may cross deletion, consent,
security, source-retention, counter-overflow, or byte-quota fences.

After a chunk has completed the canonical retention/receipt/certificate
protocol, one short K3 transaction verifies its authenticated page proof,
`leafIndex == expectedNext`, `startCursor == expectedNextCursor`, the frozen
high-water bound, and the portable content leaf, then constructs the exact
stable `.admittedArtifact` dependency member for that chunk: leaf index/cursor,
Artifact ID and typed content commitment, schema/store identity, immutable
structural-certificate revision ID/root, stable retention-admission ID,
historical admission-receipt ID/authenticated-byte commitment, and required
immutable owner receipt. Mutable currentness fields remain excluded as required
by the ordinary dependency protocol. The transaction appends the content leaf
to the portable MMR, the complete dependency member to the dependency MMR, and
the pair `(leafIndex, ArtifactID)` to a bijection accumulator before advancing
the group lease. A byte-equal chunk with another lawful admission cannot be
silently substituted.

It never walks or structurally parents the prior chunk. A crash resumes the
exact paired frontier; every append has a fixed budget independent of archive
age. There is no per-volume rollover or volume chain: any source whose frozen
counts fit the admitted UInt64/canonical-byte bounds can make arbitrary bounded
progress across the paired MMRs, while overflow is rejected before scanning as
typed unavailable. Million-row archives are therefore ordinary, bounded, and
restartable rather than falsely complete partial volumes.

Before root construction, K3 seals the completed MMR rows into one immutable
`BASArchiveIndexedMembershipRevision` header with index domain,
portable-content root/peaks/count, durable-dependency-union root/peaks/count,
leaf-index↔ArtifactID bijection root/count, source-snapshot root, and
implementation-row HWM. The three counts must be equal. The closed structural-
edge union gains `.artifactParent(...) | .certifiedIndexedSubtree(kind,
membershipRevisionID, root, count, indexDomain)`. The `.root` body contains the
exact archive-subtree edge whose `root` is the durable-dependency-union root;
its structural certificate validates that edge, both paired roots, equal
counts, and the bijection in O(1), and the head adds only the ordinary
`.admittedArtifact(root)` dependency member. The portable container carries the
matching per-chunk dependency leaf/membership proof as detached existing K3
history evidence; the root never embeds an unbounded list. Final adoption
atomically replaces the finite build lease with the durable root pin and closes
non-authoritative staging. The immutable indexed membership rows remain proof
infrastructure, not currentness or a retention authority; cleanup resolves any
leaf's concrete admission/certificate/receipt pin through the root certificate.
Deleting staging, advancing beyond 72 hours, or reopening one random leaf
cannot lose that proof.

The membership revision identity is a domain-separated canonical logical
commitment that independent decoders can recompute from the header fields; it
is never a SQLite rowid, file offset, actor identity, or ambient store handle.

A `.root` contains byte-equal canonical source-snapshot bytes and proof, one
closed terminal case `.emptySource(canonicalEmptyAccumulator)` XOR
`.sealedAccumulator(finalRoot, boundedPeaks, terminalCursor, leafCount,
scannedCount, includedCount, excludedCount, reasonRoots, byteCount,
membershipRevisionID, portableContentRoot, dependencyUnionRoot,
bijectionRoot)`, a fixed-size portable envelope, and final
accumulator proof; it never embeds an unbounded chunk-ID list. Empty input has
zero chunks and one canonical empty root. One O(1) K3 transaction verifies every
lane's scanned count/HWM against the frozen source count, all reason/included/
excluded roots against the authenticated page and policy accumulators, the
sealed paired MMRs, equal counts, bijection, and membership revision, then
adopts only the root and closes the build lease. Root→leaf proof is logarithmic
and structural Artifact depth stays
fixed. Omit/duplicate/reorder, fake empty root, gap/overlap, stale source cut,
changed leaf, forged page/peak, or incomplete membership fails.

The root envelope binds:

- the minimal bootstrap codec/algorithm IDs required to parse the root, plus
  schema/codec descriptor root/count and registry root;
- the canonical source-snapshot body/proof, source-universe epoch, ordered
  portable-content and durable-dependency MMRs, index↔Artifact bijection,
  immutable membership-revision identity, portable public-verifier bridge roots,
  fixity, provenance, per-domain roots/counts, and exact coverage posture;
- fixed retention, deletion, tombstone, cryptographic-suite, key-generation,
  and authorized-re-encryption commitments; and
- one strict external-copy phase:
  `.notExported`,
  `.preparedCopy(baseArchiveManifestID/root, copyOperationID,
  copyAccumulatorRevisionID/root, destinationCommitment, purpose,
  destinationRetention, currentEpochs, k4UseProof,
  sealedExternalExportRowProof)`, or
  `.observedCopy(baseArchiveManifestID/root, copyOperationID,
  matchingPreparedManifestID, copyAccumulatorRevisionID/root,
  terminalOwnerReceipt, deleteQueryReconcilePosture)`.

W6's first source root is always `.notExported`; all destination/grant/receipt
fields are absent. Once it is admitted, its existing Artifact ID/root becomes
the immutable `baseArchiveManifestID/root` for every copy operation. A prepared
copy may be created only after its request, K4 use, and sealed `externalExport`
row exist, and it cannot predict a terminal receipt. Its only manifest parent
is that already-existing base. An observed copy may be created only after the
matching prepared manifest and immutable owner receipt exist; its only
copy-posture parent is that matching prepared manifest. A second copy again
branches from the same base—never from an earlier prepared/observed copy.
Cross-copy predecessors, an observed-as-next-base chain, or a sealed request
that names its future prepared/observed manifest are corruption.

The existing K3 external-copy implementation rows maintain one append-only,
certified indexed accumulator keyed by
`(baseArchiveManifestID, copyOperationID)`. Its immutable membership revision
binds the fixed `prepared → observed` phase order, typed request/receipt
commitments, deletion/query/reconcile posture, and index↔copy-identity
bijection; it is neither a head nor a new Store/owner. Each optional
copy-posture manifest points directly to the base and one immutable accumulator
revision, so structural depth remains constant across arbitrarily many copies.
Authorized archive re-encryption and custody migration use the same bounded
base-plus-operation accumulator pattern rather than a predecessor list. No
immutable root is rewritten and no future operation/receipt ID is guessed.
Variable-cardinality dependency inventory,
schema/codec bytes, migration chain, external-effect/provider dispositions, and
rehydrator vectors are the bounded chunk-entry cases above and are committed by
the fixed domain roots/counts rather than embedded unbounded in this envelope.

The root's own normal admission/adoption/certification receipts are created
after the root and travel only as detached, self-excluding existing K3 history
proofs in the exported container/external-copy lineage. They are never predicted
inside the root or used as its Artifact-ID preimage. An independent decoder may
verify them as prior-admission evidence, but they grant no restore or effect
authority.

The archive is storage-independent and cannot assume SQLite rows, Swift ABI,
Apple Keychain object identity, or one model portfolio. At least Swift and one
independent Rust or Python implementation must decode, verify, and round-trip
canonical fixtures into inert staging bytes. Independent decoders have zero
authority to install rows, advance heads, issue grants, or replay effects.

Restore is Host-closed multi-owner staging, not a fake cross-database atomic
write. Before any lane import, the existing K3 restore-operation row commits a
stable restore ID, current K4 restore-use proof, trusted archive/admission and
portable-verifier proofs, exact target Workspace/Session/incarnation, the
archive-source-universe epoch/posture, and one immutable target-baseline vector.
That vector contains every destination owner's lineage/store incarnation,
current root/count/HWM/rollback-anchor generation, current conversation/Mission
and other logical heads, and deletion/privacy/consent/revocation/share/
external-copy/key-generation floors. It selects exactly one mode:
`.freshEmptyNewLineage`, `.sameLineageMerge`, or `.foreignInert`. A caller cannot
mix owner proofs, change the destination, or infer a mode from an empty-looking
table.

Every baseline component is explicitly the pre-restore predecessor captured
before the first row for that restore ID is appended. Creating the K3
restore-operation row is itself the first member of a domain-separated,
operation-local restore delta; it is never mistaken for ambient target state.
For K3 and for each boundary owner, the protocol freezes a closed allowed
restore-row-kind set and accumulates `restoreLocalDeltaRoot/count/HWM` under the
stable restore ID. Canonical row commitments exclude cumulative root/anchor/
proof fields, and the K3 projection excludes its own final activation metadata,
so neither a delta nor its expected successor root commits itself. A row from
another operation, an ordinary target mutation, or an unlisted extension can
never enter this projection.

`freshEmptyNewLineage` requires every destination lane and logical head to be
canonical genesis and creates one new restore incarnation; it never reuses a
source anchor generation. `sameLineageMerge` requires authenticated ancestry.
If the source is an ancestor of the target, only missing immutable historical
evidence may be added and all newer target heads/floors remain. If the target is
an ancestor of the source, an explicit fast-forward is legal only with zero
divergent/newer descendant proof and exact head-predecessor validation. Security,
deletion, consent, privacy, revocation, key, and rollback floors are always the
componentwise maximum and can never decrease. Concurrent/divergent lineage,
an unknown current external-copy/delete/revoke posture, or a foreign source is
`.foreignInert`: bytes may be inspected in staging but no ordinary head or
authority can activate.

The Artifact custodian, K3/Event owner, publication journal, and effect journal
each use their sole existing writer to import only their authenticated lane into
non-authoritative staging. Each owner creates a destination restore transition
from its exact target-baseline predecessor anchor—not by installing the source
root—and produces an immutable readiness receipt binding restore ID, mode,
source lane root, canonical import map, destination predecessor root/generation,
the complete operation-local delta root/count/HWM, and the deterministic new
destination successor root/generation. It proves
`currentAnchor == deterministicSuccessor(baselinePredecessor,
exactRestoreLocalDelta)`; it does not claim that the physical anchor remained
equal to the baseline while staging was written. Repeating the same restore is
byte-equal lookup; the same restore ID with changed source, target, map, delta,
or mode is corruption. Owner promotion remains hidden behind the restore
activation generation, so a crash after any subset of owner transitions
exposes no partial ordinary state.

Readiness alone is historical proof, not a cross-database CAS. Before final K3
activation, the K3 restore operation keeps the Host closed, fences creation of
new ordinary operations, and requires every pre-existing physical handoff to
reach its already defined terminal/indeterminate posture. Each sole owner then
provides an authenticated drain proof that no open callback, autonomous
completion, claim, receipt materializer, or other source can lawfully append a
row while the barrier is pending; otherwise restore fence installation is
typed unavailable until that source closes. Each sole owner then
acquires only its own mutation lease, reopens its expected deterministic
successor, and conditionally installs one durable
`restoreActivationFence(restoreID, expectedSuccessor)` as the closed terminal
row of that owner's local restore delta. The fence row's commitment excludes its
resulting root, proof sidecar, and authenticator; the owner COMMIT produces one
authenticated fence receipt binding the pre-fence successor and resulting
fenced anchor. If the current anchor changed before this CAS, fence installation
fails and the restore cannot continue under that baseline.

While a fence is pending, that owner rejects every mutation other than the
byte-equal restore activation/abort transition for the same restore ID. It does
not hold a lease across actors, call K3 from inside its transaction, or create a
second currentness head. A late ordinary receipt, claim binding, external
outcome, or unrelated row is typed deferred/retry-only and cannot advance the
fenced anchor; any already-indeterminate external result is later handled by
same-ID query/reconcile rather than silently inserted. Crash recovery reopens
the fence by restore ID. The fence is a temporary owner-local mutation barrier
inside the incumbent journal/anchor, not a new Store, owner, or authority.

Restored publication/effect/Provider/export/lifecycle rows are historical or
same-ID reconcile evidence only. The staged K3 import attaches an immutable
`archiveOriginReconcileOnly` fence to every restored possible-start decision,
including one whose original snapshot preceded its physical claim. That fence
forever prevents an original dispatch claim or replay of the original effect.
When the external API genuinely supports status lookup, a separately typed
query/reconcile operation may pass through the ordinary pending/K4/
`possibleStartCommitted` protocol under the original external operation ID; its
sealed request contains only the authorized query and never the original effect
payload. Absence of that API remains typed indeterminate/unavailable.

Outside transactions, K3 gathers each owner's destination readiness/new-anchor
proof and authenticated activation-fence receipt. One O(1) K3
activation-generation transaction rechecks the current K4 use, trusted
archive/verifier proof, `archiveSourceUniverseEpoch`, every immutable
pre-restore predecessor, every complete operation-local delta, and every fence
receipt against the exact deterministic pre-fence successor and resulting
fenced anchor. K3 never reads or CASes an owner database inside this transaction;
the still-active owner fences make transaction-external proofs current rather
than merely historical. K3's own current root must equal the self-excluding
expected K3 restore-operation successor before the transaction appends the
activation-committed delta. The same transaction rechecks destination
predecessor/successor receipts, head ancestry, and all monotonic security floors
before selecting the restored state. Any ambient K3/owner write, concurrent
target advance, stale deletion epoch, added/removed/changed restore row,
partial owner set, rollback generation, post-baseline root masquerading as a
predecessor, or mixed proof changes an expected successor/fence and aborts
activation without undoing inert staging.

After that COMMIT, each owner uses only the authenticated K3 activation or abort
receipt to advance its fence idempotently to `activatedAwaitingOpen` or to
release an aborted restore, and returns a content-free acknowledgement. The
activated fence continues rejecting ordinary writes. K3 commits `restoreOpen`
only after every exact owner acknowledgement is reopened; the Host and ordinary
readers remain closed before that point. A later owner mutation must first
reopen the K3 `restoreOpen` proof outside its lease, then clears the local fence
in the same owner transaction as its next lawful row. Thus there is no
proof→ambient-write→K3-COMMIT window and no cross-actor lease. A crash after any
fence, after all fences, before/after K3 activation, or during acknowledgements
resumes or authentically aborts under the same restore ID. After `restoreOpen`
every dependency is already anchored. A missing lane, fence, acknowledgement,
or receipt remains typed partial/unavailable rather than exposing half-restored
state. This is K3-orchestrated owner-written import using the existing
databases, not a `RestoreStore`, new owner, source-anchor installation, or K3
write into an owner journal.

Logical canonical manifest and fixity equality are required; authorized
re-encryption creates a new enclosing replay-manifest Artifact ID, contained-
envelope digest, and custody lineage rather than pretending ciphertext
equality.

External effects are never re-executed as historical replay. Their evidence may
be replayed or simulated; a possibly started real effect remains same-identity
reconcile-only. `ThisDeviceOnly` content requires an explicit authorized
export/re-encryption ceremony; absence leaves it device-bound. Export cannot
extend source retention, and any deletion/revocation/taint epoch change makes
the external copy stale and blocks use until its destination receipt is
reconciled. Raw ordinary transcripts, HumanFit, immutable-share bodies,
protected holdouts, Sub-agent hidden reasoning, and local exactNative cache
images are excluded by default.

W5 installs only the admitted generic `BASToolInvocation`/`BASEffectBroker`
egress mechanism and performs zero future certification work. W6 admission and
certification perform zero real export; they only commit and reopen the replay
manifest and certification evidence. After W6 completion, export choreography
is exact:

1. the outer runtime reopens the W6 manifest/certification and creates a stable
   export operation ID plus canonical `BASToolInvocation` typed request content
   commitment that
   binds source, destination, purpose, retention, deletion, the already-existing
   base/source manifest ID/root, and the current external-copy accumulator
   predecessor. It never binds a future prepared/observed successor root;
2. K3 records pending under that operation;
3. K4 grants/anchors the exact request;
4. the sole `BASEffectBroker` seals and reopens the exact inert request as the
   closed `externalExport` operation-kind row in
   `BASEffectBrokerSQLiteStorage`, with zero external I/O and no export journal;
5. K3's own transaction-external authenticated owner-outbox preflight produces
   the exact invocation-local snapshot defined by the ordinary possible-start
   protocol; K3 binds only its content-free row/proof identity and commits
   `possibleStartCommitted`, the sole irreversible handoff linearization point;
6. the admitted W5 generic egress adapter claims the outbox handoff once and
   executes without importing a W6
   module or type;
7. the broker records observed and terminal receipts; and
8. destination delete/query/reconcile receipts remain bound to the same
   operation and external-copy lineage.

The outer composition cannot bypass pending/K4/sealed-outbox/
`possibleStartCommitted` merely because it can read the archive. W5 never
assumes a future receipt exists.

## Primary external factual anchors

The Apple-specific boundaries were checked against Apple's primary material:

- `PrivateCloudComputeLanguageModel` and its availability/quota/context APIs:
  <https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel>;
- Apple's PCC integration guide:
  <https://developer.apple.com/documentation/FoundationModels/adding-server-side-intelligence-with-private-cloud-compute/>;
- WWDC26 “Build with the new Apple Foundation Model on Private Cloud
  Compute,” including explicit model injection, network/quota posture, 32K
  context, and reasoning segments:
  <https://developer.apple.com/videos/play/wwdc2026/319/>;
- WWDC26 “Integrate on-device AI models into your app using Core AI,”
  including explicit `LanguageModelSession(model:)` and offline
  `coreai-build` AOT compilation:
  <https://developer.apple.com/videos/play/wwdc2026/326/>; and
- Apple's Private Cloud Compute security guide:
  <https://security.apple.com/documentation/private-cloud-compute/>.

These live URLs are research anchors, not candidate authority. Tasks 0–2 must
pin the installed SDK interfaces, tool identities, relevant source snapshots,
and exact evidence digests before any Apple claim becomes admissible.

## Degradation contract

- PCC unavailable: local mechanisms continue; PCC is typed unavailable.
- One local portfolio role unavailable: unrelated roles continue; no identity
  fallback or silent substitution.
- No generative Provider: deterministic, structured, human, tool, and admitted
  non-generative mechanisms continue.
- No language inference: non-language learned, deterministic, human, and tool
  mechanisms continue.
- No learned inference: deterministic and structured human/tool mechanisms,
  identity, K3, Work/Automation, effects, and recovery continue with zero
  learned assets in the selected physical closure.
- No Apple capability or production App target: platform-neutral core,
  Work/Automation, and manual/foreground paths continue; Apple rows remain
  disabled.
- K4 or effect boundary unavailable: read-only planning and projection
  continue; Provider handoff and mutation are blocked.
- Learning certification unavailable: evidence remains quarantined; policy
  promotion is blocked.
- Performance target missed: the performance claim is disabled; correctness
  behavior is unchanged.
- MorphoHDL unavailable: no product behavior changes.
- Historical external Provider unavailable: evidence remains verifiable when
  possible; hidden state is unavailable and external effects are not replayed.

## Failure and recovery rules

- A pre-put reservation crash leaves a finite empty reservation; a
  post-put/pre-bind crash leaves a reservation-addressable
  `recovery72Hours` body. Neither leaves an unenumerable orphan or visible
  half-commit.
- A post-admission/pre-Artifact-receipt crash leaves K3-owned canonical receipt
  bytes and pending materialization, repaired byte-identically before use.
- A post-K3/pre-Artifact receipt crash leaves a pending materialization record;
  recovery emits the one canonical receipt byte sequence before consumption.
- A changed retry under one semantic operation key is corruption.
- A lost reply first reopens the stored receipt.
- A global-head-only conflict may retry the same semantic operation after
  stable-key lookup; a logical predecessor conflict may not.
- A stale epoch, revoked share, deleted body, missing key, or changed App-Agent
  selection fences recovery before projection or execution.
- A possibly crossed Provider, publication, command, or effect boundary is
  query/reconcile-only under the original identity.
- A prepared output without a matching delivery receipt remains durable but is
  not projected as a visible reply.
- A writer-budget or audit-budget exhaustion returns a resumable bounded
  continuation and never retries the same unbounded history scan under the
  writer lock.
- Missing optional acceleration causes recompile/replay, not a fabricated
  terminal state.
- An unprovable recovery quality is typed unavailable rather than silently
  downgraded.

## Verification design

After this design receives legal source admission, Task 2 adds the derived,
non-authoritative evidence file
`docs/superpowers/evidence/qinao-historical-requirement-crosswalk-v1.json`.
It is not an eighth controlled document, registry, adoption decision, or
runtime input. A pinned generator reads only the closed admitted-source
registry and controlled candidate while explicitly excluding its own output,
then emits canonical key-sorted UTF-8 JSON. The file records generator
identity, `admittedInputSetRoot`, row count, and a domain-separated digest of
the canonical `rows` value. It does not contain its own full-file digest or a
tree root that includes itself. Existing Task-2 candidate/admission evidence
binds the completed file's byte length and SHA-256 from outside the file. Each
row contains:

- stable requirement ID and source fingerprint;
- normalized intent;
- adopted boundary or research-only disposition;
- existing owner, Wave, path, and symbol;
- top-level versus contained classification;
- exact selector for a production-adopted invariant, or a closed
  `notApplicable(reason)` disposition for research, rejected, non-goal, or
  control-turn rows;
- production status and external blocker;
- superseded or duplicate requirement links.

The crosswalk cannot create or broaden authority; it only proves coverage.
Every production-adopted row must be represented in the seven controlled-document
transplant. Filler acknowledgements and continuation commands remain accounted
for as non-feature control turns rather than silently disappearing.

Each biomimetic or experimental topic uses two rows when applicable: the
research proposition is `researchOnly + notApplicable(reason)`, while the
shipping authority/reachability prohibition is `productionAdopted` and points
to an exact negative selector. The selector is a foreign key into the canonical
test ledger; the crosswalk cannot create it.

At minimum, exact tests cover:

- the V1→V2 transition-02 supplemental-design bundle within the unchanged
  nineteen-position registry, externally fixed amendment identity, five-state
  presence matrix, ref-CAS, retry/lost reply, V2 design-tree predecessor gate
  for Task 2/W0, historical V1 replay, and preserved 03–19 logical order;
- generalized retention identity and six-class presence matrix;
- sole-store `prepareIdentity` key ownership, authenticated reserved-put
  authorization, K3 `identityPreparing` commitment-key-epoch pin before
  transient prepare, reserve→claim→put→bind, forged/default/foreign-store/
  generation rejection, storage-auth and commit-proof algorithm/key-epoch/
  verifier binding, byte-equal ticket/proof reopen across process restart and
  proof-key rotation, kill-after-identityPreparing-row-before-token-return,
  ordinary pre-attach expiry/terminal cancellation/late-token rejection,
  historical-receipt obligation renewal under the same immutable bytes/key/
  identity epoch after deadline, reboot, and auth-key rotation,
  kill-after-Artifact-COMMIT-before-return repair,
  verify-only key retention, fixed unsigned-body domain separation, self-
  digest/final-tag-inclusive digest rejection, wrong commit-coordinate
  rejection, cleanup-versus-queued-put, reboot/clock-domain renewal, exact
  retry, trusted 72-hour guarantee, zero unenumerable orphan cuts, and two
  concurrent semantic reservations for one byte-equal Artifact receiving two
  independent claim bindings without rewriting content identity;
- admission/operation/promotion receipt COMMIT→Artifact put→structural-
  certificate installation crash cuts, byte-equal repair, immutable
  `historyDecisionRevision` versus monotonic materialization revision,
  kill at decision/attach/ticket/Artifact-COMMIT/completion, rejection of final
  mutable row revision as receipt identity, decision-body/root/receipt preimage
  self-exclusion with final-root/future-ID mutation rejection, the closed
  `.admittedArtifact | .k3HistoryReceipt` dependency-member union, foreign/
  missing history-row rejection, T-own-receipt rejection with legal T+1
  inclusion, and zero receipt-of-receipt recursion;
- per-Artifact edge-closed structural-certificate induction, per-head
  accumulator membership, omitted-grandparent/forged-root rejection, bounded
  delta/work, resumable `pendingClosureBuild`, stale predecessor, count/height/
  epoch overflow, paginated audit pause/resume, retention promotion and custody
  re-encryption leaving immutable structure/accumulator leaves valid, current
  decision/custody/deletion vectors absent from immutable leaves, deletion
  currentness failing
  O(1) without descendant recertification, bounded algorithm-successor
  activation, and proof that foreground cost is independent of total history;
- transaction-external Artifact preflight, full K3 revision-vector recheck,
  `BEGIN`-to-COMMIT zero `await`/I/O, injected actor reentrancy, competing second
  request, and Artifact↔K3 lock-order/deadlock mutations;
- exact top-level/contained classification and acyclic
  body/receipt/envelope/graph/manifest/checkpoint lineage;
- v1/v2 Artifact canonicalization separation, immutable identity plus append-
  only custody generations, confidential keyed/domain-separated content
  commitment, zero public bare digest/exact length, actual pre-AEAD canonical
  padding and outer-BLOB bucket equality, short-value offline-dictionary
  resistance, wrong/missing erasure salt/class/ciphertext length, re-encryption
  flip crash cuts, bounded bottom-up successor-DAG migration, high-fanout
  immutable referrers, migration-verifier-keyed v1 commitment with zero raw v1
  identity digest, scope/erasure/edge-aware 1:N v1 resolution and ambiguous bare
  lookup rejection, zero in-place ID rewrite, and zero dual currentness/fallback;
- immediate `recovery72Hours`→`userDurable` promotion at `t = 0`, the
  `259199999ms` boundary, orphan cleanup, lost reply, and receipt-materializer
  crash repair;
- durable-head transitive dependency horizons and structural-proof pinning;
- atomic input-head plus executable-plan commit under one stable semantic key;
- atomic prepared-output plus terminal-plan commit, followed by receipt-gated
  visible publication and zero pending-reply context/learning/reward ghost;
- audit-row-before-output, host-display-before-crash, output-before-delivery,
  delivery-reply-loss, and process-restart publication cuts, proving no generic
  `alreadyProcessed` state and zero direct raw-result-to-UI reachability;
- effect/Provider/BGTask pending→K4 use→sealed owner-outbox reopen→content-free
  K3 `possibleStartCommitted`→one durable handoff claim→at-most-one physical
  handoff→terminal process-death
  cuts, unforgeable transaction-external owner-outbox snapshot/proof, wrong
  owner/store/incarnation/root/revision/credential-generation rejection,
  byte-equal K3 pending-row/deadline/operation-maximum/minimum-slack/capability-
  use binding, K3-transaction zero owner/K4/Keychain I/O, reciprocal
  unforgeable K3-possible-start proof before an owner handoff claim, sealed-row-
  without-PSC rejection, start-before-delete/delete-before-start linearization,
  nonextendable claim deadline bounded by credential/key availability,
  authenticated K1 `claimLinearizedAt`, injected suspension at the final
  conditional statement through deadline, late-COMMIT rollback/expired branch,
  authenticated expired-definite-nonstart versus claimed-
  indeterminate, delete between COMMIT/journal/syscall, outbox pin/expiry/
  key-erasure acknowledgements, in-memory token/bundle-map loss, zero re-mint/
  redispatch, zero prompt/message/secret/request bytes in K3, sealed-outbox
  orphan cleanup before start, and typed indeterminate when the external API has
  no query, plus exact boundary-kind→publication/effect-journal and credential-
  class→issuer/lease-owner ledger equality with zero Provider/BG third journal,
  and issuer-generation `active→fencing→draining→retired` crash/race coverage
  proving fence-new-leases, paginated two-journal drain, PSC reconcile-key
  retention, issuer destroy acknowledgement, and zero early key retirement;
- Main/Whisper interleaving, branch-scope isolation, physical-head rebase, and
  predecessor-free adoption-key lost-reply handling, including commit→lost
  reply→caller-observes-successor and same-ID/different-bytes rejection;
- strict-ancestor continuity, wide/deep/duplicate/digest/overflow cycle
  rejection, and complete ancestor retention reopen;
- concurrent Sub-agent A/B deterministic adoption, same-key changed-content-
  commitment corruption, terminal/cancel/currentness races, non-CoT restart,
  and no second
  milestone head;
- the exact long-chain selector above proving at least 128 turns and 32
  interruption/reopen cycles preserve objective, constraints, conversation and
  Mission heads, identities, context, pending/next work, visible results, and
  possible-start cardinality across archive and compaction, with a verified
  pre-cut EventLog prefix, closed row-by-row recovery suffix, and zero hidden
  authority drift;
- legacy UserState migration and zero raw exporter reachability;
- strict `plaintextV0 | envelopeV1` UserState physical presence matrix,
  one-shot nonescaping plaintext buffer, plaintext/WAL/SHM/backup migration and
  cryptographic erasure, tag/row mismatch rejection, arbitrary URL/default-all/
  plaintext-temp export rejection, strict total-order pagination,
  canonical-source-chain/causal-partial-order proof, source-root row-count
  equality, and coverage-deficit fail-closed behavior;
- one W0 Persona/UserState inventory root consumed unchanged through W6, a
  migration-only reader with zero production reachability, and zero free-form
  Provider instructions;
- caller-minted AgentSpec/write/commit/visibility and persona-warrant rejection,
  finite internal detector threshold, LOW-tier output validation, and restart
  requiring current K3/K4 authority rather than serialized claims;
- plaintext Application-Support HMAC, API-key argv/environment/raw-header/log/
  snapshot rejection, opaque credential handles, and zero sample-secret Release
  reachability;
- HumanFit identity/style separation, expiry/provenance, zero durable codec or
  export, and current-Attempt non-adoption;
- self-ID-free share request → sole K4 `issueCapability` put →
  reserve/claim/lookup use lifecycle, reply-loss recovery, version/presence
  matrix, exact-seven preservation, zero caller put, and zero
  write/learn/cache/export/reshare;
- accepted-token equality with authorized accepted output;
- local exactNative checkpoint eligibility over all source sensitivity and
  erasure domains versus secret-bearing/lossy/remote negative paths, including
  zero put/admission/receipt for non-exact cache, zero arbitrary-URL/raw
  safetensors API, composite cache identity, fail-closed encryption/protection,
  and cross-Workspace/App-Agent/Attempt restore rejection;
- the seven production physical roots and five checked-in physical harness
  manifests, exact package allowlists, resolved/show-dependencies graphs,
  normalized DAG, required-positive mechanism rows, source/link/resource/test
  closure, zero duplicate compatibility module, and exactly four semantic
  runtime profile identities;
- Qwen/MiniCPM/Granite/KaLM full numerical role ABI, golden vectors, and
  reachability from manifest through real consumer; exactly five model slots
  plus the non-model classifier binding in the same sole composition call,
  classifier factory→composition→real consumer positive reachability, and zero
  optional/sixth-slot/self-registration/second-seam escape;
- one compiler byte/receipt across every legacy callsite and one W4-router-
  selected Provider/Attempt/ordinal binding with K3 persistence but zero K3/
  broker election, registry-recency/default/fallback re-election, or same-
  Attempt alternative retry;
- predecessor-authorized protected Python rotation, pre-start static sealed-
  object/toolchain proof with zero child first-instruction marker before
  `possibleStartCommitted`, post-start child attestation, kill/quarantine with
  zero second spawn, authorized rollback, and zero bare authority-tool lookup;
- Apple/BGTask inventory completeness, W4 zero PCC invocation, W5
  pending→K4→sealed `effect.zone-c-saga.remoteProvider` row→content-free K3
  `possibleStartCommitted` before the earliest unproven API→one durable handoff
  claim→one model instance→classified checks→zero-or-one session/respond order,
  W6 physical cutover, zero unclassified PCC prewarm, separate W5/W6 operation
  identities, VisualIntelligence/ImagePlayground disabled reachability, split-
  package ingress placement, and no
  availability-to-authority path;
- AOT observable/opaque/graph-specialization separation, Release-zero
  `makeLibrary(source:)`/`MLModel.compileModel`, and classified
  `MPSGraph.compile` call graph;
- correctness-projection equality, unknown-field fail-closed behavior, and
  path-exact normalization for every performance claim;
- FEP/DMN/grokking/MorphoHDL zero-authority mutations;
- portable archive K3-first causal vector cut across Event, Artifact identity/
  claim-binding/custody, publication, and effect lanes; authenticated canonical
  source-snapshot bytes/proof that survive deletion of the source databases;
  bounded owner-authenticated page preflight plus portable membership/policy
  proof; public-key-verifiable per-lane portable bridges with MAC-only
  `deviceBound/portableUnavailable`, original-device/Keychain loss, MAC-secret
  export rejection, and verifier/anchor/bridge-root mutation; eligible↔excluded
  same-count mutation rejection; closed archive-entry
  and included/excluded/post-cut unions; per-reason and per-lane
  scanned=included+excluded=source-count equality; bounded crash-resumable
  independent chunk leaves plus paired UInt64/64-peak portable-content and
  durable-dependency MMRs, exact index↔ArtifactID bijection and complete
  `.admittedArtifact` leaf, progress-renewed finite inactivity lease, large-N
  multi-renewal completion, stalled expiry, finite-source-horizon preflight,
  canonical empty/single/million-leaf cases, overflow-before-scan typed
  unavailable, zero partial-volume completion, immutable certified-indexed-
  subtree finalization, fixed Artifact depth and logarithmic leaf proof after
  staging closes and more than 72 hours pass; ten-million-leaf
  `archiveSourceUniverseEpoch` O(1) deletion/currentness fencing; variable inventories carried as
  chunk entries rather than an O(N) root; fake-empty/gap/overlap/forged-page/
  forged-peak/omit/duplicate/reorder/self-or-final-tag-inclusive rejection;
  strict `.notExported | preparedCopy | observedCopy` external-copy phases with
  immutable base root, fixed-depth per-copy branches, certified K3 copy
  accumulator, repeated-copy/cross-copy/future-successor mutations, and zero
  future-receipt prediction; W1 contract/W2 K3-row/W6 codec dependency
  direction; Host-closed Artifact/K3/publication/effect owner-written restore
  with current K4 use, closed fresh-empty/same-lineage/foreign-inert modes,
  pre-restore target predecessors, closed operation-local delta roots/counts/
  HWMs, deterministic destination successor equality, self-excluding K3 restore
  projection, destination predecessor/successor anchor receipts, authenticated
  owner drain proofs and owner-local activation fences, proof→ambient-write→K3-
  BEGIN rejection with zero cross-owner transaction/lease, activation/abort/
  acknowledgement/`restoreOpen` crash recovery,
  componentwise monotonic security floors, stale-delete/wrong-target/proof-mix/
  concurrent-target/ambient-owner-or-K3-row/changed-delta/post-baseline-as-
  predecessor/partial-owner/repeated-restore and every owner-promotion crash
  mutation, including no-contention success, O(1) K3
  activation, zero original-effect restored handoff, and separately authorized
  content-free same-ID query/reconcile where supported; cross-
  version/cross-implementation inert rehydration, re-encryption lineage,
  destination retention/revocation, W6 zero real export, and pending→K4 use→
  sealed `effect.zone-c-saga.externalExport` row→content-free K3
  `possibleStartCommitted`→reciprocal K3 proof→one broker handoff choreography;
- crosswalk input-root self-exclusion, rows-subtree digest, external full-file
  identity, research/firewall row split, and selector foreign-key closure;
- replay never redispatching an external effect;
- Artifact legacy-head write fence→bounded staging→O(1) activation crash cuts,
  high-row-count progress, zero public head writer/link reachability, and K3-only
  currentness after cutover;
- caller-cutoff EventLog prune rejection, `userDurable` TTL immunity, trusted
  recovery minimum, every Release EventLog caller/conformer using throwing typed
  errors with zero `[]`/`0`/fresh-state fallback, authenticated K3/EventLog and
  owner-journal roots, canonical inner-row/root outer-proof self-exclusion,
  row-extension rejection, Artifact identity/claim-binding/custody accumulator
  equality, per-owner mutation-lease/no-cross-actor lock order, pending-anchor
  visibility gate, valid-row rewrite and consistent-backup rollback rejection,
  canonical source identity/predecessor
  ordering, federated identity/typed-content-commitment deduplication, causal
  partial-order coverage deficit, and partial-copy deletion reconciliation; and
- deletion epoch-first fencing, late-result non-resurrection, local/derived/KV/
  share/archive/external-copy acknowledgement completeness, every boundary-
  owner frozen root/HWM/count and outbox/credential/handoff cursor, late-seal
  drain, Artifact outer-anchor generation plus identity/claim-binding/custody
  root/count/HWM/cursor equality and late binding/generation drain, parent/child
  projection watermark/rebuild, direct-parent erasure-domain AND binding,
  recursive erasure-closure commitment, stale scope-root O(1) read rejection,
  over-fan-in typed-unavailable behavior, late pre-fence put claim, forged-empty-
  frontier rejection, and exact pending/partial/indeterminate versus completed
  projection.

The current ordered predecessor selector set is frozen at 222 with Wave
partition `85/46/9/14/13/55` and hash
`696fb383e79c30bedc4a321c13b7e715c73b0e9423e40fa1259c0d90691f7558`.
New semantic invariants append unique selectors by default. A deletion or
rename requires a one-to-one supersession row plus semantic and mutation
equivalence proof. After the whole design is transplanted, one generator
recomputes the total, per-Wave partition, ordered hash, every
`--require-test`, suite gate, risk mirror, and bidirectional missing/extra
mutation. No broad selector may conceal a new invariant.

## Rejected alternatives

### Patch each historical requirement independently

Rejected because it creates duplicate heads, self-ID cycles, reverse Wave
dependencies, incomplete legacy migrations, and selector drift.

### Add a Conversation Store, Persona Store, Share Store, or Milestone Store

Rejected because each creates a second truth beside Artifact Mesh and K3.

### Keep direct `userDurable` precommit bodies and collect them as orphans

Rejected because permanent retention and routine orphan collection are
contradictory.

### Put a body first and add its retention row afterward

Rejected because a crash between stores creates an object with no stable
operation identity or trusted horizon. K3 reservation must precede every
resumable put.

### Reopen the complete history inside every K3 transaction

Rejected because safety work grows with conversation age and eventually makes
the sole writer permanently unavailable. Foreground commits use an inductive
closure root plus bounded delta; complete verification is paginated outside the
transaction.

### Keep Artifact CAS heads beside K3 heads

Rejected because two durable mutable currentness families can diverge after a
crash or partial migration. Legacy Artifact heads are fenced and imported once;
the Artifact Mesh is immutable-body storage afterward.

### Treat an audit row or in-memory spent set as publication/effect truth

Rejected because process death loses the spend state while a nonterminal audit
row can also suppress an undelivered result. Possible-start boundaries require
durable owner journals and same-identity reconciliation.

### Use separate CAS operations for message and plan roots

Rejected because crashes can expose a message without a plan or a released
reply without its terminal graph.

### Add a per-Sub-agent milestone head

Rejected because the Mission graph root already owns accepted progress.

### Treat a filtered monolithic Swift test as model-erased

Rejected because its package/test dependency closure still contains forbidden
adapters and packages.

### Persist every local or remote KV image

Rejected because lossy and remote hidden states are not recovery truth. Only a
strictly scoped local exactNative acceleration image is eligible.

### Let performance, model confidence, framework availability, or research
scores select authority

Rejected because capability and truth derive from receipts, policy, and
currentness rather than empirical convenience.

### Guarantee literal century-long bit-for-bit execution

Rejected because durable usability requires canonical formats, fixity,
independent decoders, cryptographic agility, and periodic migration rather than
one frozen implementation.

## Acceptance boundary

This blocked design input is ready for legally admitted Task-2 transplant into
the existing controlled implementation authorities only after:

1. the user approves this written specification;
2. self-review finds no placeholder, ambiguous authority, unclassified wire,
   reverse dependency, self-ID cycle, or partially enabled migration;
3. an externally fixed, user-approved Tasks-0–2 amendment legally admits this
   exact file through V2 transition 02 before any Task-2 candidate read or W0
   transition and pins its external identity;
4. the active annex maps every production-adopted section into Task 2 and the
   seven controlled documents;
5. authoring tests fail on each rejected alternative and cross-domain
   contradiction;
6. the canonical selector predecessor/successor bijection, Wave partition,
   ordered hash, suite/risk mirrors, and mutation proof all close; and
7. no production W1-W6 code is written before the controlled plan is admitted.

Admission never turns this file into an implementation plan, runtime
authority, or eighth controlled document. It remains non-authoritative design
input after its adopted requirements have been transplanted.
