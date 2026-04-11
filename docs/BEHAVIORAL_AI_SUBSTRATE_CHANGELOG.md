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

### Notes

- The contract is intentionally fast-evolving and private. Breaking changes are allowed, but they must be recorded here and in the migration notes.
