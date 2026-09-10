# Explicit provider identity — focused verification

Base: `695d3db1e87a0d574df26f29f664d2a6f812cc0d`. This records the Task5
registry/endpoint migration, not whole-package success or DS3 readiness.

Configured endpoints now bind an exact provider ID for eager, decision-aware
and streaming invocation. Registration order, advisory rankings, later provider
registration and unavailable selected providers do not elect a replacement.
Legacy serialized registry errors remain supported. Model choices, transport
and the separate shared-operation contract are not changed by this slice.

The frozen source/test patch is SHA256
`a4dd4d9f2b66da5586c14d0c91fb7cc089d19f0d30c479ca160f5c3a3b9e6434`.
The source-compatible absence probe first executed and failed with the three
intended missing-ID/role-election/LIFO violations; after the repair it passed.

| Verification | Executed | Skipped | Failed |
|---|---:|---:|---:|
| Implementer BAS registry/matrix/adapter suites and exact identity boundary | 58 | 8 | 0 |
| Implementer Qinao identity/error/routing/factory/loop suites | 73 | 15 | 0 |
| Implementer no-endpoint/non-streaming controls | 9 | 2 | 0 |
| Root fresh BAS registry and exact identity boundary | 7 | 0 | 0 |
| Root fresh Qinao identity and error translation | 14 | 0 | 0 |

Executed counts include skips; they are not all passed-test counts. Skips are
existing explicit real-provider opt-ins or unavailable-path controls on a host
where FoundationModels exists. No live-provider/model-download flags were enabled.

Root's exact selectors were
`BASOrganRegistryTests|BASProviderBoundaryTests/testRegistryResolvesOnlyAnExplicitProviderID`
and `BASOrganRegistryEndpointIdentityTests|QinaoOrganErrorTranslationTests`.
Each ran with `swift test --package-path <package> --build-system native
--scratch-path <existing-package-scratch> --filter <selector>` under
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` and
`MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib`.
The scratches were `/private/tmp/qinao-bas-native-test-1329bde3` and
`/private/tmp/qinao-sdk-native-test-7806dc5a`, used serially. Both root commands
ended exit0. The native backend's deprecation warning remains a toolchain
limitation, not a suppressed diagnostic or evidence for the default backend.

Root log SHA256 values:

- BAS: `86680e76c2baa531bd3cf409af80612d7cefa50ea03cc6d0bc7cfc7d6b82e1cd`
- Qinao: `9979e80bf0d17671685545949f9fce8c8509d835c9f48e4a507ce77b4d4721bf`

The complete report, original/final logs and frozen patch remain in the private
plan workspace. Root verified the patch matches current sources with read-only
reverse-apply checking and confirmed the only executable role-lookup references
left in the four named package source/test roots are the two deliberate absence
probes. `git diff --check` passed.

Fresh independent task review found the slice spec-compliant and approved its
quality, with no Critical or Important issue. The sole Minor observation is
native-backend deprecation/log interleaving, retained for final branch review.
The BAS production-default failure and both Qinao provider-inversion/shared-
operation failures remain open. Full final validation, PR, fresh exact merge
approval and separate DS3 authorization are still required.
