# Keychain policy repair — scoped evidence

Date: 2026-09-10. Implements consolidated choice 5A from
`../specs/2026-09-10-qinao-approved-decisions.md`.

## Behavior

Existing Data Protection items are inspected before writing. Only observed
`WhenUnlockedThisDeviceOnly` or `WhenPasscodeSetThisDeviceOnly` accessibility is
eligible. The update query includes the observed class and changes data only;
opaque access-control metadata is neither interpreted nor replaced. Missing,
malformed, legacy or unknown protection returns `unsupportedItemPolicy` without
an automatic upgrade, deletion/recreation or successful-write receipt.

Fresh item policy remains `WhenUnlockedThisDeviceOnly`. Native macOS retains its
existing backend and data-only update behavior; it is not claimed device-bound.
Load/delete/provision behavior remains unchanged. The API documentation states
that raw Ed25519 seed material enters process memory; this is not nonexportable
Secure Enclave signing.

The focused nondefault `KeychainRegression` plan retains the three selected
Keychain/audit/commit-token classes, with the eight existing model/endurance/fuzz
flags disabled. The original default device plan is preserved. Tests use owned
disposable exact tuples and checked cleanup, not user signing keys.

## Verification and review state

Initial independent review accepted the production boundary and found two
Important test-harness defects: unchecked native setup-error restoration, and
an empty non-Security test pass. Fix round 1 shares checked setup/teardown
restoration, preserves ownership until set/read/matching-value checks succeed,
and emits explicit platform skips. The public store comment and retained RED
diagnostic classification are corrected in the same round.

Observed covering logs:

| Candidate / platform | Executed outcome |
| --- | --- |
| Initial final hosted three-class candidate | 36 selected, 1 platform skip, 35 passes, zero failures |
| Fix 1 restoration-fault methods, native | 3 passes, zero failures |
| Fix 1 complete Keychain class, native | 17 selected, 4 platform skips, 13 passes, zero failures |
| Fix 1 complete Keychain class, iOS 27 simulator | 14 selected, 1 platform skip, 13 passes, zero failures |

The initial audit/commit-token implementations and assertions are unchanged by
fix 1; the final covering rerun is the changed Keychain class, not another full
three-class baseline. Linux execution was not performed. The initial behavioral
RED contains a genuine refusal-test failure, but its surrounding capture was
interrupted after the test summary; it is not represented as a naturally
completed command. RED-only corrupted-JSON and profile-write diagnostics are
separate from that behavioral failure, not claimed repaired.

Both final commands naturally exited zero and the implementer released both
build directories. Scoped fix re-review approved specification compliance and
code quality: all two Important and two Minor findings addressed, no new delta
breakage. Root read both reports, independently matched all six final source
hashes and checked the final test summaries and whitespace diff. Tests were not
rerun for review.
Detailed original evidence, preserved reviewed source, commands, raw logs and
file identities are retained beneath
`.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/task-11-*`.

## Limits and remaining requirements

- Simulator/helper coverage does not establish physical passcode, biometric,
  backup/restore or a real ACL-protected/passcode-class item update.
- Readable legacy fixtures preserve seed, identity and signatures after refusal;
  a workflow that must replace an old key still needs an actual recovery path.
- No production `store`/`provisionOrLoad` caller was established in the scoped
  review. End-to-end host handling of refusal is not demonstrated here.
- Native test UI suppression uses deprecated process-local APIs, with checked
  restoration. Source-only non-Darwin skips are not counted as exercised controls.
- Existing bounded synthetic device-test startup diagnostics are not model,
  cloud/PCC or full endurance runs. No real-device execution occurred.
- This is a scoped code repair, not blanket closure of historical findings,
  completion of all DS3 prerequisites, merge authority or permission to start DS3.
