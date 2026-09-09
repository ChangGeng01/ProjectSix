# Remote provider response bounds — scoped verification

Task3 of the solo DS3-readiness plan repairs existing DS1
`occ_0335bc4ba9b93ef6ecf90884`. Base:7806dc5a57e97162b339b6bdffac1be8060de8b2.
The complete five-file implementation/test diff has SHA256
`c40f504a567eba8b60adcdc85714af662b3d81a38775269e7eb3b7fb53aa0fd8`.

Both Chat Completions entrypoints now account for raw receipt synchronously
before retention. Ignored SSE framing/metadata consumes the same response
budget; decoded output is also bounded before append. Consumer-driven streaming
preserves every returned delta and cumulative body without a producer queue of
cumulative copies. Absolute request deadlines and request-local cancellation
cover headers, idle receipt and paused consumption. Injected sessions are not
replaced or invalidated. Background sessions fail explicitly because Foundation
does not support the required task-specific delegates there.

## Actual evidence

- Before production edits: four entrypoint tests produced five expected failing
  assertions, while the legitimate exact-cap control passed. Whole nonstream
  receipt and ignored streaming bytes escaped their intended bounds; a delayed
  response escaped its deadline.
- Frozen implementation:48 tests passed, zero failures or skips, including20
  new incremental offline URLProtocol cases and28 existing adapter/parser cases.
- A fresh independent static reviewer found no concrete surviving bypass or
  blocking regression. It independently checked task-delegate API availability
  and documented forwarding of unimplemented methods to the injected session.
- Root's post-review run on identical source also passed48 tests, zero failures
  or skips; build7.03s, tests1.766s, process exit0. Full output SHA256:
  `abec09d8a64c606c3244b7901dcf864e94e75f11288e8d0d80b6f30565696f5c`.

From this worktree, using the installed Xcode27 and its same-source real MLX
library, the exact post-review command was:

```sh
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --package-path BehavioralAISubstrate --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --filter 'BASChatCompletions(OrganAdapter|Streaming|ResponseBoundary)Tests'
```

These temporary paths identify the actual run, not prerequisites embedded in
product code. Detailed logs, source hashes and review are retained privately in
this plan's SDD workspace. The native-backend deprecation warning remains.

## Limits

The guarantee is O(cap) adapter-owned state, not a precise process-memory quota
over Foundation/OS buffers, callback arguments or caller-retained chunks. Live
provider interoperability and real authentication/redirect/cache challenges
were not exercised; configured headers/URLProtocol and injected-session survival
were. No model download or external provider was used.

EOF without `[DONE]` remains compatible with the previous implementation. This
does not resolve separate DS1 `occ_3b9638705586b4899e5de6b2` concerning terminal
completeness and downstream publication/audit. Other package failures and
DS1/DS2 issues remain separately tracked. This is not full-suite or DS3 readiness,
merge approval, or authorization to launch DS3.
