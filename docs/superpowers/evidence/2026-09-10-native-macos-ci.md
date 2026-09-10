# Native macOS CI bridge — bounded evidence

Status: implementation independently approved after one fix round; not yet a
hosted pass.

The bridge keeps six CI jobs and all existing product tests/checks.
BAS/Qinao use the current native SwiftPM backend and a same-checkout MLX metallib
built by upstream CMake3.31.6 in a fresh isolated directory. The compiler helper
uses the SDK-resolved compiler for that path, while its existing direct-Xcode
checks remain the default for SampleHost. A successful metallib build supplies
the following test step's path; setup/build/missing-artifact errors stay fatal.

The Qinao boundary entry points preserve their default behavior and accept one
explicit native backend choice. CI selects it for both the build and nested
symbol emission. All scanning rules and failure behavior remain unchanged.
The native boundary-only path does not execute tensor code, so it has no separate
Metal component/metallib preparation step. SampleHost's iOS commands are unchanged.

Local evidence preceding implementation:

- One native symbol-graph command built and exited0, producing25 JSON files in
  `<scratch>/arm64-apple-macosx/symbolgraph`:19 library primary graphs,5 extension
  graphs, and a zero-symbol graph from the retained test build. All manifest
  library products are represented. This proves relative layout, not a redaction
  verdict or fresh test execution. Full output and emitted graphs are preserved.
- One local SampleHost scheme listing exited0 and identified workspace/scheme
  `SampleHost`. Log-store and empty-supported-platform warnings remain. This
  does not prove an iOS destination, build, tests or hosted-runner equivalence.

Implementation fixture evidence:

- Genuine initial RED:16 tests with25 expected failed assertions for the missing
  helper/workflow and resolver/backend behavior; first GREEN16/16.
- Complete tool regression:90/90. The first run's process handle was lost while
  its saved log completed; one unchanged repeat captured observed exit0. Both
  logs are retained. This was evidence-recovery overhead, not a code improvement.
- Self-review reproduced an inherited-CI-environment fixture failure, corrected
  its explicit default setup and added a missing-output-file case. The amended
  boundary/helper focus passed26/26 with the native CI environment selected.
- Independent review found a functional relative-path defect and a final-suite
  chronology gap. A genuine relative-path regression failed before the helper
  canonicalization and passed afterward. The final exact five-module suite then
  passed91/91 in64.154s with observed exit0 on the complete amended source.
  This run covers an actual fix, not an unchanged retry. Full log SHA-256:
  `bb9e6e05b1b62bca59d3d5888d740dc7e6bcb0aa774f8295642944d6126863a7`.
- The same independent reviewer verified both findings addressed, with no new
  breakage: spec compliant, quality Approved,0Critical/0Important/0Minor.
  The37line fix-only diff is retained separately from the original candidate:
  `902a5b08c93ef9bf5e8cb4904900d79f2cea15601d2a3316df3b3d8af0b313da`.

Fixtures execute the actual shell/workflow commands against isolated fake
install/build tools. They do not install components, compile/run product code,
invoke models/cloud/PCC, boot a simulator or prove the hosted environment works.
Exact commands, outputs and identities are in the solo workspace's
`task-19-report.md` and associated logs. Both original and fix-round reviews
are preserved. Real hosted product validation remains a separate next step.

Native is currently available but deprecated: this is a tactical build bridge,
not a durable toolchain guarantee. Prior CI failures remain preserved. SampleHost
previously stopped in compiler preparation before its product build/tests; no
product test failure or success should be inferred from that stop. No merge or
DS3 is approved, and overall DS3 readiness remains unachieved.
