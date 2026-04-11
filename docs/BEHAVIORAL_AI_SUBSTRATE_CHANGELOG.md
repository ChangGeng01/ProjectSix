# BehavioralAISubstrate Changelog

## 2026-04-11

### Added

- Introduced `BASHostKit` as the façade-first private SDK product.
- Added `BASHostConfiguration`, `BASHostDependencySet`, `BASHostRuntime`, `BASHostSessionRequest`, `BASHostSessionResult`, `BASHostLifecycleRequest`, `BASHostReopenRequest`, and `BASHostConsoleConfiguration`.
- Added `SampleHost` as a minimal iOS façade integration example.
- Added package tests covering façade bootstrap, session start, and reopen flows.
- Added `check_sdk_import_boundaries.sh` to keep host targets on the façade import surface.

### Changed

- `Before`, `BeforeWatch`, and shared host source now import `BASHostKit` instead of low-level BAS modules.
- `project.yml` now treats `BASHostKit` as the primary host-facing dependency.
- `BehavioralAISubstrate` package structure is now documented as a private SDK delivery shape rather than only an internal substrate.
- `BASHostKit` façade now prefers generic host vocabulary such as `interactive`, `ambient`, `rapid`, `deliberate`, and `reflective` instead of exposing `Before` product language at the SDK boundary.
- Structured truth, current-brain mode identifiers, and provider observation narratives now prefer substrate-owned generic identifiers such as `primary`, `comparative`, and `reflective`.
- Reserved open-model slot identifiers are now substrate-owned (`substrate/open-model-slot`) instead of carrying `Before` branding.
- Host preview labels and other product phrasing now live in `Before` mappings instead of package-owned preview formatters.
- Provider runtime narration now refers to the host app generically instead of naming `Before`.
- Entry-intent, pending-launch, and deferred-reopen package surfaces now prefer generic workflow vocabulary like `capture`, `present`, `reopen`, `resume`, and `routedInput`, while legacy host raw values remain accepted at the bridge edge.
- `BASHostKit` now exposes host-owned presentation configuration so app-specific workflow titles, session titles, and follow-up phrasing can live in the host instead of the substrate default copy.
- `BASHostKit` host-owned presentation now also covers lifecycle notices, predictive intervention copy, reopen wording, and empty-prompt fallback copy, so substrate defaults stay generic while hosts own visible tone.
- `BASHostKit` now also exposes host-owned workflow behavior configuration, so template IDs, retrieval defaults, memory-source mapping, and verification/provenance namespace can live in each host instead of staying frozen inside substrate defaults.
- `Before` now injects its own `Quick Judgment / Balance Board / Mirror` presentation profile through `BASHostConfiguration.presentation`, while `SampleHost` continues to use the generic façade defaults.
- `Before` now also injects its own workflow behavior namespace and template IDs through `BASHostConfiguration.workflowBehavior`, while `SampleHost` proves a second host can carry a different namespace and workflow template set without forking SDK logic.
- `SampleHost` now proves that a second host can inject a totally different presentation profile (`Rapid Lens / Compare Lens / Reflective Lens`) without forking substrate logic.
- Identity role titles in the substrate default profile are now more generic (`Stability Guide`, `Comparative Guide`, `Reflective Witness`, `Risk Sentinel`) so persona flavor can be layered back in the host instead of leaking from the SDK core.

### Notes

- The contract is intentionally fast-evolving and private. Breaking changes are allowed, but they must be recorded here and in the migration notes.
