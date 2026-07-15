// MLXOrganAdapter+SessionPersist — B5 KV 跨会话持久化 production surface (opt-in API, ADR-014:
// nothing calls these unless a host explicitly does — e.g. the dream-loop idle window snapshotting
// warm seats, or app-relaunch warm-start).
//
// F6 gate (Mac, 1177-token session): fp16 restore 6ms vs cold re-prefill 279ms = 45.7×, 48/48
// exact greedy continuation; Q4 tier 33.6×/~8KB-per-token with tie-break-class divergence.
// Goes through BASSessionKVStore (NOT the upstream savePromptCache — which drops
// ArraysCache.offset, corrupting the GDN mask geometry on restore).
import Foundation
import BASOrgan
import BASRuntimeCore

#if canImport(MLXLLM)
import MLX
import MLXLMCommon

extension MLXOrganAdapter {

    /// audit x-sov #6 — diagnostic hook for a KV-snapshot Data-Protection
    /// failure (test seam). The persist path used to `try?`-swallow the
    /// setAttributes error; it now surfaces here. nil ⇒ unobserved (default).
    nonisolated(unsafe) static var _sessionProtectionFailureHook:
        (@Sendable (Error) -> Void)?

    public enum SessionPersistError: Error {
        case noSuchSession(String)
        case notLoaded
    }

    /// Snapshot a pooled session's trunk cache to `url` (fp16-exact by default; `quantizeKV`
    /// = the Q4 space tier). Call between turns — never mid-decode (the serial lock guarantees
    /// consistency, but a mid-stream snapshot captures a half-turn).
    @discardableResult
    public func persistSession(
        sessionID: String, role: BASOrganRole = .core, to url: URL, quantizeKV: Bool = false
    ) async throws -> Int {
        guard let box = _sessionBox(sessionID: sessionID, role: role) else {
            throw SessionPersistError.noSuchSession(sessionID)
        }
        return try await Self._persist(box, url: url, modelID: model.id, quantizeKV: quantizeKV)
    }

    /// The streamBody idiom: the @unchecked Sendable box crosses the region boundary; the session
    /// inside is only ever reached via this actor (the ChatSessionBox contract).
    /// `modelID` binds the snapshot to its producing model (audit mlx-adapter-core MED-10).
    static func _persist(
        _ box: ChatSessionBox, url: URL, modelID: String, quantizeKV: Bool
    ) async throws -> Int {
        let bytes = try await box.session.withLiveCache { cache in
            try BASSessionKVStore.save(cache: cache, tokenCount: 0, to: url,
                                       modelID: modelID, quantizeKV: quantizeKV)
        }
        Self._protectSnapshot(at: url)
        return bytes
    }

    /// 缝2 / x-sov #6 (device-recon id2): apply Data Protection to the KV
    /// snapshot and SURFACE any setAttributes failure via the hook (was
    /// `try?`-swallowed). Split out of `_persist` — which needs a live
    /// ChatSessionBox+model — so this security branch is Mac-unit-testable on
    /// its own, parallel to the atom-store path (id1). No MLX types touched.
    static func _protectSnapshot(at url: URL) {
        // Readable after first unlock (background restores keep working),
        // sealed in the pre-unlock window. Routed through the shared
        // BASSQLiteFileProtection helper (same class, kill-switch, +sidecars).
        if let err = BASSQLiteFileProtection.apply(toDatabaseAt: url.path) {
            _sessionProtectionFailureHook?(err)
        }
    }

    /// Warm-start a pooled session from a snapshot: fresh model cache ← restored state, wrapped
    /// in a ChatSession and installed under `sessionID#role` (replacing any existing session).
    /// `instructions` must be nil when the snapshot already encodes the system prompt (it does,
    /// for sessions persisted after their first turn) — the upstream re-tokenization trap.
    /// `generateParameters` must be supplied for bounded decoding — restored sessions do NOT
    /// inherit any prior session's parameters (the spill-cert unbounded-generation lesson).
    public func restoreSession(
        sessionID: String, role: BASOrganRole = .core, from url: URL,
        instructions: String? = nil,
        generateParameters: GenerateParameters = .init(maxTokens: 512, temperature: 0)
    ) async throws {
        guard let container = _loadedContainerForStreaming() else {
            throw SessionPersistError.notLoaded
        }
        struct CacheBox: @unchecked Sendable { let cache: [KVCache] }   // actor-confined handoff
        let expectedModelID = model.id   // audit mlx-adapter-core MED-10: reject a wrong-model spill
        let box: CacheBox = try await container.perform { ctx in
            let fresh = ctx.model.newCache(parameters: nil)
            _ = try BASSessionKVStore.restore(into: fresh, from: url, expectedModelID: expectedModelID)
            for c in fresh { eval(c.innerState()) }
            return CacheBox(cache: fresh)
        }
        let session = ChatSession(container, instructions: instructions, cache: box.cache,
                                  generateParameters: generateParameters)
        await _installSession(session, sessionID: sessionID, role: role)
    }
}
#endif
