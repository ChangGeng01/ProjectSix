# Manifest-selected MLX default — focused verification

Base: `601ef2873813636385058d2549aa561c1275e7bd`. This is the bounded
Task6 construction change, not model certification or DS3 readiness.

The no-model Qinao MLX factory now resolves the existing BAS production
manifest (`mlx-community/Qwen3.5-4B-4bit`) by exact catalog identity. It
checks the manifest's positive peak estimate against the resolved positive
active cap before loading, and refuses without choosing another model.
Explicit model experiments and LoRA targets remain explicit. Certification
is a separate, unchanged three-Gemma list; Qwen remains experimental.

The original default-ownership regression executed and failed with the two
expected catalog-default/competing-recommendation violations before changes.
The implementer's final focused verification executed 111 BAS and 26 Qinao
tests: 137 passed, zero failures and zero skips. Coverage includes exact
identity, unknown-model refusal, cap boundaries, one load/no retry, legacy
explicit choices, speculative controls and sample endpoint caching.

The initial 14-file source/test patch was independently reviewed. Review
identified one broad-catch test weakness; the fix now asserts the exact
unknown-model error and declares its existing local product test dependency.
A temporary unrelated CancellationError was rejected by the repaired test;
the restored 12-test suite passed without failures or skips. Scoped re-review
confirmed the finding addressed with no new Critical/Important issue.

Final 15-file source/test/manifest patch SHA256:
`98a59adcbd482acbf6cb0b8b3dfa18282c49f815b7e17c764c9c10f615368d9e`.
Root independently matched the patch, checked reverse applicability against
current sources and verified fresh post-review results: 4 BAS boundary tests
and 12 Qinao factory tests passed, zero failures/skips, both commands exit0.
The original evidence remains preserved, not replaced by the follow-up run.

Root selectors: `BASProviderBoundaryTests` and `QinaoMLXEndpointTests`.
Both used `swift test --package-path <package> --build-system native
--scratch-path <existing-package-scratch> --filter <selector>`, serially,
with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` and
`MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib`.
Scratches: `/private/tmp/qinao-bas-native-test-1329bde3` and
`/private/tmp/qinao-sdk-native-test-7806dc5a`.

Root log SHA256 values:

- BAS: `b668567ba289eed3f20db801202d293f64b1a776187c6db2ab5878f48e4d1e74`
- Qinao: `38494b146d3639ef0b645bc2804ed386765d582833f3f606c4487332d86507a5`

Full reports, commands, logs and both patches remain in the private plan
workspace. Root-owned planning/validation changes are outside the source
patch hash. `git diff --check` passed. Task6 is accepted for ordinary commit.

No real model download/load, inference, training, device/app launch or opt-in
provider test was activated. Native-backend deprecation and pre-existing
compiler warnings remain visible. Estimated admission is not an OS memory
guarantee. The general device-runner selector is separate pending work.
Both existing Qinao provider-inversion/shared-operation baseline failures
remain open; final coherent validation, PR, fresh exact merge approval and
separate DS3 authorization are still required.
