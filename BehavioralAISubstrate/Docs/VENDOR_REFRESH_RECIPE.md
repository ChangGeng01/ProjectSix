# Vendor refresh recipe — how to re-vendor `Vendor/` to latest without losing the patches

> Executed end-to-end on 2026-06-11 (branch `vendor-latest-refresh`, commit `fd7233805`: everything → latest,
> mlx-swift-lm 2.x → 3.31.3 major included, zero regressions). This document exists so the NEXT re-vendor
> doesn't have to reconstruct the procedure from commit messages. Every step below was empirically necessary —
> skipping any one breaks the build, the offline promise, or silently drops the patches.

## What lives in `Vendor/`

- **15 upstream packages** (path deps; see `Package.swift` `dependencies:`): the 3 roots `mlx-swift-lm`,
  `swift-transformers`, `swift-huggingface` + their full transitive closure (mlx-swift, swift-nio,
  swift-collections, swift-crypto, swift-asn1, swift-atomics, swift-numerics, swift-system, swift-syntax,
  swift-jinja, EventSource, yyjson).
- **2 of OURS — never touched by a re-vendor:** `bas-rust-binaries` (Rust XCFramework), `mamba-ssm-fixtures`.

## The FOUR patch classes that MUST be ported (they die silently if forgotten)

> **Apply order for the two that touch `Evaluate.swift`:** class 2 (ADR-038 wedge instruments) FIRST, then class 3
> (rejection sampling) — class 3's diff is cut against the post-ADR-038 file.

0. **Vendor warning suppression** — `Docs/patches/vendor-suppress-warnings.diff` (apply with plain `git apply`).
   Kills ALL vendored-package compiler warnings (8338 → 0 under Xcode 27) so first-party diagnostics stay
   visible: (a) a tail loop appended to 7 manifests (swift-nio, swift-syntax, swift-collections, mlx-swift,
   mlx-swift-lm, swift-transformers, EventSource) adding `-suppress-warnings` (Swift) / `-w` (C/C++) via
   `unsafeFlags` — PERMITTED because path dependencies are exempt from SwiftPM's unsafeFlags ban; (b)
   `-Wno-shorten-64-to-32` on the Cmlx target's c/cxxSettings; (c) `#pragma clang diagnostic ignored
   "-Wc++17-extensions"` atop 2 Metal headers (steel_attention.h, integral_constant.h) — the Metal frontend
   ignores manifest settings, only the pragma reaches it. If new packages gain warnings after a refresh,
   append the same tail loop to their manifests and regenerate this diff.

1. **M224 url→path rewrites** — each vendored manifest's `.package(url: …)` deps pointing at vendored siblings
   become `.package(path: "../<sibling>")`. In swift-nio + swift-crypto, the upstream manifests have a
   `SWIFTCI_USE_LOCAL_DEPS` env conditional — replace the whole if/else with the unconditional path-deps branch.
   Leave `swift-docc-plugin` / `swift-xet` / `async-http-client` urls alone (SwiftPM prunes unused/trait-gated
   deps; they never resolve). 8 manifests carried rewrites in the 2026-06 refresh: mlx-swift, mlx-swift-lm,
   swift-transformers, swift-huggingface, swift-jinja, swift-crypto, swift-nio, EventSource.
2. **ADR-038 MLX wedge instruments** — 7 files across mlx-swift + mlx-swift-lm (opt-in `Event::wait` timeout,
   `MLX_WEDGE_TRACE` tripwires, scheduler-throttle diagnostics, Gemma per-layer eval beacons,
   `basSurfaceEvalError` binding fix). Archived as a portable diff:
   **`Docs/patches/adr038-mlx-wedge-instruments.diff`** — apply with plain `git apply` (NOT `--3way`: the index
   still holds the old vendor, so 3way fails with "does not match index"). It applied cleanly across the
   2.x→3.31.3 major; if a hunk ever fails, port by hand and REGENERATE the archived diff.
3. **Spec-decode rejection sampling** — `Docs/patches/spec-decode-rejection-sampling.diff` (apply with plain
   `git apply`, AFTER patch class 2 — both touch `MLXLMCommon/Evaluate.swift`, and class 3's diff is cut against
   the post-ADR-038 file). Adds the distribution-correct sampling lane to the vendored `SpeculativeTokenIterator`:
   a public `SpeculativeAcceptanceStrategy` enum (`.argmaxEquality` = upstream default / unchanged behaviour;
   `.rejectionSampling` = Leviathan accept-with-prob `min(1,p/q)` + residual `(p−q)₊` resample), threaded through
   the speculative `generate(...)` / `generateTokens(...)` free functions. The greedy/argmax path stays
   byte-identical (the new branch is reached ONLY when a caller passes `.rejectionSampling`). Mirrors BAS's
   host-proven `BASSpeculativeRejectionSampler` (algorithm verified on host; MLX port's distribution-equivalence
   certified on-device). If a hunk fails after a refresh, port by hand (re-add the enum, the `acceptanceStrategy`
   init param + stored field, the `switch acceptanceStrategy` in `speculateRound`, and the two free-function
   params) and REGENERATE the archived diff.

## Procedure (the 2026-06-11 run, verbatim-reusable)

```sh
# 0. Clean tree + a NEW branch pushed first (the swap is ~1000 files; keep the old state remote-safe).

# 1. Resolve the latest CONSISTENT graph in a scratch package (never hand-pick transitive versions):
mkdir -p /tmp/vendor-staging/resolver/Sources/resolver && cd /tmp/vendor-staging/resolver
#   Package.swift depending on the 3 roots at their latest tags (exact:), one empty source file,
#   then:  swift package resolve
#   → Package.resolved = the authoritative pin set; .build/checkouts/ = the new vendor sources
#     (SwiftPM materializes mlx-swift's C++ submodules — VERIFY Source/Cmlx/{mlx,mlx-c,json,fmt,metal-cpp}
#      are non-empty before swapping).

# 2. Swap (zsh: use a LITERAL for-in list — unquoted $VAR does not word-split in zsh):
for p in EventSource mlx-swift mlx-swift-lm swift-asn1 swift-atomics swift-collections swift-crypto \
         swift-huggingface swift-jinja swift-nio swift-numerics swift-syntax swift-system \
         swift-transformers yyjson; do
  rm -rf "Vendor/$p" && cp -R "/tmp/vendor-staging/resolver/.build/checkouts/$p" "Vendor/$p"
  rm -rf "Vendor/$p/.git" "Vendor/$p/.github" "Vendor/$p/Tests" "Vendor/$p/Documentation" \
         "Vendor/$p/cmake" "Vendor/$p/Xcode" "Vendor/$p/scripts" "Vendor/$p/Utils" "Vendor/$p/tools" \
         "Vendor/$p/skills" "Vendor/$p/IntegrationTesting" "Vendor/$p/dev" "Vendor/$p/Benchmarks" \
         "Vendor/$p/Examples"
  chmod -R u+w "Vendor/$p"     # SwiftPM checkouts are write-protected; cp preserves that
done
rm -f Vendor/*/Package.resolved   # stale remote pins — misleading to audits, read by nothing

# 3. DELETE versioned manifest variants — SwiftPM prefers Package@swift-X.swift over Package.swift,
#    so a variant with url deps silently leaks network fetches past the rewrites:
find Vendor -maxdepth 2 -name 'Package@*.swift' -delete

# 4. Port patch class 1 (url→path rewrites — see above), then patch class 2:
git apply Docs/patches/adr038-mlx-wedge-instruments.diff

# 5. Prove offline self-containment (the M224 promise):
rm -rf .build Package.resolved && swift build
#    MUST complete with ZERO "Fetching …" lines and an EMPTY .build/checkouts/.

# 6. Gates (pin the stable toolchain — the Xcode-27-beta swift test SEGVs at xctest load):
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-swift-testing   # full suite
bash ../scripts/check_mlx_redaction.sh                                                        # Qinao seam
#    + QinaoRuntimeSDK targeted suites + DeviceTestApp xcodebuild (generic/platform=iOS, own DerivedData).

# 7. Update the M224 comment block in Package.swift (provenance) + this file if the procedure changed.
```

## Known traps (each one bit us)

| Trap | Symptom | Fix |
|---|---|---|
| `Package@swift-X.swift` variants | build "Fetching <url>…" despite rewrites | delete them (step 3) |
| SwiftPM checkout write-protection | `PermissionError` on first edit | `chmod -R u+w` after copy |
| `git apply --3way` | "does not match index" | plain `git apply` (worktree-only) |
| zsh unquoted `$PKGS` loop | single-iteration cp error | literal for-in list |
| Xcode-27-beta toolchain | suite SEGV signal-11 at xctest load, 0 tests run | `DEVELOPER_DIR` → stable Xcode |
| Vendored `Package.resolved` files | stale remote pins confuse audits | delete them (step 2) |

## After-the-fact guards that exist

- `scripts/check_vendor_remote_leak.sh` (M225) — catches url leaks in the resolved graph.
- `scripts/vendor_diff.sh` / `vendor_state.sh` (M229) — dep-graph diffing helpers.
- ADR-038 §11 maintenance note — records that the wedge instruments are ported per-re-vendor via the archived diff.
