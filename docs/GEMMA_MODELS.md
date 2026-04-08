# Gemma Model Assets

Place bundled LiteRT-LM assets for Gemma under:

- `Before/Resources/Models/*.litertlm`

Current behavior in this branch:

- Before detects bundled `.litertlm` assets and surfaces them in Settings.
- The app prefers Gemma when selected, then falls back to Apple Foundation Models or deterministic local copy.
- A real LiteRT-LM iOS runtime is not linked yet, so detection currently prepares the build and fallback flow rather than running Gemma inference.
