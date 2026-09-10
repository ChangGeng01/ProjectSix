# Qinao — consolidated user decisions, 2026-09-10

## Authority and scope

The user requested every outstanding choice together, asked whether any B was
mandatory, then replied `好` to the recommendation of A with the qualifications
below. This records approval of that consolidated direction, not verification
that it is implemented. The root announced this interpretation before acting.
It supersedes earlier unanswered-design holds on these choices only.

Ordinary scoped design, implementation, tests, review, commits and development-PR
updates may proceed without repeated per-detail confirmations. Material scope
changes, additional spending/permissions, destructive data/key migration, the
exact merge candidate and starting DS3 are not implicitly authorized. Existing
tool permissions still apply. No new model, cloud/PCC fallback or reset redemption
is authorized by this decision.

## Selected choices

| # | Selected A direction | Cost or limit retained |
|---|---|---|
| 1 | Delegate ordinary technical decisions within this specification. | Record meaningful rulings; new material choices still require the user. |
| 2 | Make persistence writes report actual failures and migrate current callers; isolate transaction ownership and adjust live-model result contracts where necessary. | Source compatibility may change; existing database content/history stays. Never rollback unrelated caller edits. |
| 3 | Add strict authoritative reads; migrate recovery, projections and export consumers. Keep explicitly best-effort legacy APIs. | Unsupported strict implementations fail explicitly; errors are not empty history or permission to overwrite. |
| 4 | Retain the original audit history, attach honest per-record assurance, require hardened new writes. | Ambiguous legacy evidence is readable but cannot alone authorize dependent mutation/graph decisions. Do not re-sign old evidence or invent missing links. |
| 5 | Do not rewrite unclassifiable legacy Keychain protection; refuse the affected update without downgrading existing keys. | Preserving bytes is not proof that necessary old-key operations work. |
| 6 | New sample signing keys use exclusive owner-only creation and an explicit suitable file-protection class where supported. | Access may be unavailable before first unlock. Existing keys remain untouched; file mode is not same-user process isolation. |
| 7 | Ordinary version changes use logical compare-and-admit; previously admitted work may finish. | Physical effects may happen after a normal version switch. Recovery/rollback requires separate stale-writer isolation, below. |
| 8 | Trusted host coordinates quiescence, restoration and new-session composition; libraries verify state and commit boundaries. | Actual host wiring and failure tests are required. Arbitrary external effects cannot be universally rolled back. |
| 9 | Keep unbound legacy anchors readable but non-executable; establish new IDs only from verifiable original version/state. | Do not guess nil/unknown version as current. Necessary unusable old recovery paths remain open defects. |
| 10 | Move concrete providers and privileged ownership into the host integration leaf; migrate repository imports/construction directly. | Allow source API breaks, not data/history deletion. Keep complete real-provider test flows. |
| 11 | Stream and final result share one producer/invocation. | Failure/cancellation does not silently regenerate or fall back. Explicit later retries have distinct operation identities. |
| 12 | Prefer durable critical-state commits before dependent work, with stronger synchronization and recovery fault tests. | Accept I/O/latency costs; no promise of recovering hidden reasoning, all KV/OS state or every hardware failure. |
| 13 | Repair and retain the existing StateLake reader with checked input/size/allocation boundaries. | Do not silently promote experimental capability into a larger supported-product promise. |
| 14 | Permit suitable standard Xcode 27 preview CI for Apple jobs after checking actual availability/toolchain/destination. | Retain test scope, visible unavailable/failure results; no paid larger runner, skipped tests or weakened thresholds. |

## Required qualifications and existing decisions

- Recovery is stricter than an ordinary version change: old execution must not
  write into restored/new-session state. If the host cannot establish the required
  isolation, pause the affected recovery rather than claim success. A hung task
  must not require a global indefinitely held governance lock.
- For choices 5 and 9, if a necessary recovery path relies on an unusable old key
  or anchor, verification/migration is required before that requirement can be
  accepted. Refusal alone does not close the defect. Any consequential change to
  real old keys/data remains separately scoped, not blanket migration authority.
- Verify actual interruption/reopen reconstruction of plans, progress, results
  and operation receipts. Started-but-unconfirmed external effects remain
  indeterminate and are not automatically replayed.
- All runtime data has at least 72 hours' persistence; private side conversations
  are permanently retained. These are product requirements, not achieved claims.
- Selected local-model unavailability does not activate cloud/PCC or silently
  select another model. Only trusted host code owns issuers and halt reset.
- Preserve commits, worktrees, dirty drafts and original DS1/DS2 evidence. The
  earlier refusal to replace missing original historical evidence with a fresh
  acceptance record remains controlling. DS1 succeeded; DS2 failed; DS3 has not
  started. These choices do not resolve historical evidence gaps.

## Execution and recovery

### User clarification: persistence is an APP requirement

The user explicitly corrected priority: `我想要的 持久化 是 app的 持久化
不是 开发的`. Git/PR/CI and development reports are supporting engineering work,
NOT acceptance evidence for persistent product conversations or resumable work.
Prioritize the actual application input/plan/task/progress/result store and its
startup/interruption/reopen wiring. Preserve at least72hours of runtime records,
including temporary conversations outside long-term memory; private read-only
side conversations remain permanent. Each conversation retains its own plan and
recoverable context references. Restore completed versus pending versus unknown
effects without silently replaying uncertainty or switching to cloud/PCC.

Acceptance must exercise the actual selected App host and fresh-process recovery
at meaningful execution boundaries. Library-only tests, a saved audit ledger,
development worktrees and successful file close/reopen cannot substitute for that
workflow. Retain completed useful fixes, but do not expand development evidence/
approval machinery in place of application recovery. No promise is made to restore
unavailable hidden reasoning or every OS/model-memory state bit-for-bit.

Existing necessary CI/code review remains ordinary development, not the product
persistence deliverable. The prior DS3/no-merge authority boundary still holds.

### User clarification: retain and separate historical development work

The latest instructions are `别删除 就放着` and `最好和当前有必要 分开
删除 太浪费了`. They supersede the preceding request to remove development
persistence. Preserve its source, tests, fixtures and historical records at their
original paths; clearly label it as historical/reference work and remove its
unnecessary coupling to active ordinary development. Do not rebuild, run or
require the old custom development-admission/persistence machinery. Keep App
storage/recovery/audit and necessary CI/tests active. Do not delete or rewrite
Git history, original DS1/DS2 evidence, keys, App data or dirty drafts.

The user also directed continued implementation until DS3-ready. That means
actual product fixes and validation, not a claim that this separation alone
makes the App durable or the repository ready. DS3 remains separately approved.

Continue the existing solo plan and its finite issue ledger, without restarting
completed scans, triage or unchanged baselines. The next bounded implementation
is selected from the current progress checkpoint; the previous Task13-next
sentence is superseded, as that repair has already been completed. Relevant
RED/GREEN tests and independent review precede a completion claim.
