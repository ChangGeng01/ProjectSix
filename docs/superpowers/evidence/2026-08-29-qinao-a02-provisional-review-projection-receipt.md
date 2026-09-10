# Qinao A0.2 provisional review projection receipt

Date: 2026-08-29

Schema: `qinao.a02-provisional-review-projection-receipt.v1`

## Decision and authority boundary

The A0.2 byte-preparation and fail-closed observation sublayer is complete as
non-authoritative review evidence. It reconstructs the exact two ordered
design projections without creating a source commit, moving a source or
protected ref, invoking a signer, creating an authority claim, accepting a
receipt, or installing either tree.

It is not A0.3. The result is always blocked with exit code `40` because this
capability cannot accept or evaluate the required external V1 transition-02
predecessor evidence. That statement is about the capability boundary; it is
not a global claim that external evidence does not exist.

The protected 33-path authoring worktree was not modified. Its branch remains
`codex/qinao-dual-space-controlled-convergence` at
`29d953a8ab7f1b8cfe83ae1f99c9ace620b2f895`; its preserved identity remains
commit `4a9298db261bcfda97ea1748baad65649156ba66`, tree
`22382c1de6680a263ec4a2f4a6c989c0f0e6e220`.

Deep Scan numbering remains immutable: DS1 is the first successful scan, DS2
is the later failed scan, and DS3 has not been started or authorized.

## Fixed source and projection identities

- selected development bootstrap commit:
  `7e4aa2d626e2c94b1b1f3405fb8454e73448514f`
- selected development bootstrap tree:
  `47304602b7d1c1eba8eed571dbc65ee36c3a5f21`
- 2026-08-02 source commit / tree / blob:
  `c8f80486895e12e26d567e610c35a6e2141b3489` /
  `2f484874b8b6d49b8bcd595bf3a3ff6c835fb509` /
  `f3d4186769fd0119a418097fea8821d597770189`
- 2026-08-02 bytes / SHA-256:
  `81128` /
  `40d322f052425a7e56f03b826922181047c30ac908c35c922a5481e4ddf29aa6`
- 2026-08-10 preservation commit / tree / blob:
  `4a9298db261bcfda97ea1748baad65649156ba66` /
  `22382c1de6680a263ec4a2f4a6c989c0f0e6e220` /
  `887c23a28fb9098d86d252aa8b6dc9153380738b`
- 2026-08-10 bytes / SHA-256:
  `233726` /
  `4eb06cde16e0cf5985c7272147ced9274dd83648a098772c8b5a06f7b3ebeab6`
- exact review tree after 08-02 only:
  `4fd48205c1716f9ce23efd8885c94afdcdf70311`
- exact review tree after adding only 08-10:
  `0fa81fb9d1c3498fd8bb75d4c46a048f3b64260e`
- projection digest:
  `cf8290927c19deddc37938f7ded85a985a286923ab1501d5401879149fcb8298`

The two calculations are distinct procedures—an isolated temporary index and
a recursive tree rewrite—but share the same Git implementation and object
format. They are explicitly not represented as independent failure domains.
The exact one-path delta proves unchanged non-target Git object identities; it
is not described as an independent byte-by-byte reread of every non-target
file.

## Fail-closed content and authority model

The observer keeps three axes separate:

1. observed 08-02 and 08-10 content identity;
2. relationship to the two predicted review trees; and
3. authority state.

Exact 08-02 with absent 08-10 prepares only a non-authoritative projection.
An exact pair without authority is quarantined, never reported as
`alreadyPresent`. A foreign 08-10 path, mode, blob, duplicate, case/Unicode
alias, or path-like collision is quarantined. A missing or foreign 08-02
predecessor fails closed. Unreadable objects produce typed
`evaluationUnavailable`, not a false `absent` observation.

The subprocess closure contains only review-object operations: `init`,
`rev-parse`, `cat-file`, `ls-tree`, `read-tree`, `update-index`, `write-tree`,
`mktree`, and `diff-tree`. `git init --bare` creates an ephemeral symbolic
`HEAD` inside private scratch; that entire repository is removed after a
successful run. Authority signer, claim, commit, and ref-mutation calls remain
zero.

## Runtime resilience actually proved

- scratch root is fixed at
  `/private/tmp/qinao-a02-provisional-runtime-v1`, owner-only mode `0700`;
- every session has a `0600`, single-link lease;
- a `0600` global janitor lock serializes creation, stale-session reaping, and
  normal teardown;
- active leased sessions survive concurrent janitor passes;
- a forcibly terminated session loses its lease and is reaped on the next
  start only if path ownership, mode, and identity validation still pass;
- cleanup is descriptor-relative, does not follow symlinks, rejects device /
  mount boundaries, bounds traversal depth and entry count, and rechecks
  directory identity before removal;
- rename-swap injection fails without traversing replacement contents;
- external symlink and hardlink targets survive cleanup;
- parent Git-control variables, replace refs, ambient Python tempfile
  redirection, global/system Git configuration, hooks, and fsmonitor cannot
  redirect the accepted projection;
- command stdin, stdout, stderr, wall-clock time, tree entry count, tree path
  length, scratch entry count, and scratch depth are bounded;
- timeout cleanup kills the entire child process group even when its leader
  exited before a descendant closed inherited pipes; and
- paths containing the platform alternate-object separator are routed through
  a private scratch link and are not reparsed as multiple object directories.

## Verification evidence

- full black-box and contract suite: `35/35 PASS` in `30.493s`;
- six-process, sixty-session-per-process teardown race regression: `PASS`;
- the same concurrent regression repeated three additional times: `3/3 PASS`;
- forced-termination orphan reaping: `PASS`;
- cleanup-lock failure lease release and next-start recovery: `PASS`;
- parent-exit descendant process-group cleanup: `PASS`;
- stdout and stderr budget overflow rejection: `PASS`;
- Python compilation check: `PASS`;
- two independent CLI invocations: both exit `40`, output length `4250`, and
  are byte-identical;
- runtime-root postcondition: only `.janitor.lock` remains.

Frozen precommit file identities:

| path | bytes | SHA-256 |
| --- | ---: | --- |
| `scripts/qinao_a02_provisional_design_edge.py` | 51142 | `9229f962f9581f7f942b5f08838f0f9199810dc366e62b03cc0206fe68f09f0d` |
| `scripts/test_qinao_a02_provisional_design_edge.py` | 56397 | `d7c8339af1a6b433e4775b26c66aa28befb035aabfa7b42e33ac9092447a82fc` |
| `docs/superpowers/evidence/2026-08-29-qinao-a02-provisional-review-projection.json` | 4250 | `cab70d307dd1e289850fe741b67ad64c9a252913ddccd9ba00c13d1b065f6f2b` |

This receipt intentionally does not name its containing commit or tree. A
postcommit repository-external receipt must bind those identities without a
self-hash cycle.

## Explicit residual hard gates for A0.3

A0.2 is conditionally reproducible only while the fixed source objects remain
available and byte-exact. It borrows the mutable source object database and
does not prove an immutable source-object epoch. A0.3 must first create and
reverify a private immutable object-closure snapshot.

If the Python parent itself is killed while a child command is running, this
observer does not guarantee orphan process-group termination. A0.3 requires an
external supervisor with durable PGID plus process-birth identity, not merely
another in-process `finally` block.

This observer enforces wall-clock and pipe-byte budgets, but it is not an OS
capability sandbox and does not impose address-space, process-count, FD, or
file-size limits. It is for the fixed trusted local A0.2 inputs, not an
untrusted-repository service. A0.3 requires a separately confined helper with
OS resource controls.

Descriptor-anchored deletion and identity checks materially resist same-UID
namespace races, but they are not capability isolation from another malicious
same-UID process. The external authority ceremony must treat that distinction
as a hard gate.

Until those gates and the real external predecessor evidence are satisfied,
A0.3, A0.4-A0.5, A1-A4, R0-R3, and Deep Scan #3 remain unopened.
