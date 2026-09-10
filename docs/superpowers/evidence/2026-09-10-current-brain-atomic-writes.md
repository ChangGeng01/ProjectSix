# Isolated current-brain and checkpoint writes

The current-brain and evolution-checkpoint writers now stage changes in a new,
autosave-disabled SwiftData context. They do not save or roll back unrelated
pending edits in the caller's context. Fetch/save failures throw; results contain
immutable stored-field values and are returned only after the required save.
Combined checkpoint/update writes share one context and one save.

The approved source migration requires `try`, removes the old save-error
callbacks through the host call chain, and replaces live-model result arrays
with values. Existing ordering, deduplication, relinking, forget matching and
72-hour retention behavior are retained. No historical data migration occurred.

Focused native verification on the proposed source: 61 tests across five suites,
zero failures/skips, natural exit0. It includes:

- A genuine pre-fix reproduction of unrelated caller-row commitment.
- Caller insert/update/delete isolation and strict read/save failure propagation.
- Combined-stage failures without a committed checkpoint/update half.
- Successful file-store reopen with both record types.
- A real read-only SwiftData save throwing Cocoa error513; reopen retained only
  the seed row. This is separate from injected pre-save test failures.
- Public host propagation of a real two-configuration refusal, with no call to
  `buildCurrentBrain`. That test is configuration refusal, not host save failure.

Independent spec/quality review approved this slice with no open findings.
The supported transaction scope is one standard
SwiftData configuration; empty/multiple configurations are refused. This is not
proof of custom-store, external-writer, abrupt-kill or hardware-failure atomicity.
A failed real save may have uncertain effects and is not automatically replayed.
Earlier preparation callbacks are not rolled back by this storage transaction.
Routed-memory intents, governed-memory/projection writes and complete host
recovery isolation remain separate work. No whole-finding closure or DS3
readiness is claimed from these tests.
