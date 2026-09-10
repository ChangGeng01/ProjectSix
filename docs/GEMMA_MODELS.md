# Gemma Model Assets

Place bundled LiteRT-LM assets for Gemma under:

- `Before/Resources/Models/*.litertlm`

Recommended current asset:

- `gemma-4-E4B-it.litertlm`
- expected size: `3,654,467,584` bytes

Current behavior in this branch:

- Before detects bundled `.litertlm` assets and surfaces them in Settings.
- Known Gemma assets are checked for expected size so partial downloads do not masquerade as ready bundles.
- The app prefers Gemma when selected, then falls back to Apple Foundation Models or deterministic local copy.
- A real LiteRT-LM iOS runtime is not linked yet, so detection currently prepares the build and fallback flow rather than running Gemma inference.
- `.litertlm` assets are ignored by default in Git because they are too large for ordinary repository history.
