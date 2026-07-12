// charter audit 2026-07-12 T4 — compatibility re-export. The pure-Swift Apple
// lifecycle/executor/config types moved to BASAppleLifecycleKit (so BASHostKit can link
// them WITHOUT the model-invoking half of this module). Every existing
// `import BASAppleAdapters` keeps seeing the full surface through this re-export.
@_exported import BASAppleLifecycleKit
