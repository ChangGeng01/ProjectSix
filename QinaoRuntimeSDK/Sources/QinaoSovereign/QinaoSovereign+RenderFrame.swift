import Foundation
import BASOrchestration

extension QinaoSovereignControlPlane {

    // MARK: - L12 render frame storage
    //
    // BASRenderFrame is in BASOrchestration; the BAS sovereign
    // ledger lives in BASSovereign and importing the cognition
    // module there would create a dep cycle, so this storage
    // lives on the Qinao composition layer.
    //
    // Semantics: LWW on `(sessionID, turnID)`; first-seen tuple
    // order preserved; FIFO eviction when a NEW tuple would
    // push past `renderFrameCapacity`.

    /// `(sessionID, turnID)` is explicit because the L12 schema
    /// doesn't embed them. LWW on an existing key replaces in
    /// place without eviction; new keys past the cap evict the
    /// oldest entry.
    public func recordRenderFrame(
        _ frame: BASRenderFrame,
        sessionID: String,
        turnID: String
    ) {
        if let idx = renderFrameEntries.firstIndex(where: {
            $0.sessionID == sessionID && $0.turnID == turnID
        }) {
            renderFrameEntries[idx] = (
                sessionID: sessionID,
                turnID: turnID,
                frame: frame)
            return
        }
        if renderFrameEntries.count >= renderFrameCapacity {
            renderFrameEntries.removeFirst()
        }
        renderFrameEntries.append((
            sessionID: sessionID,
            turnID: turnID,
            frame: frame))
    }

    public func renderFrame(
        sessionID: String,
        turnID: String
    ) -> BASRenderFrame? {
        renderFrameEntries.first {
            $0.sessionID == sessionID && $0.turnID == turnID
        }?.frame
    }

    /// Every render frame for a session, in first-seen order.
    public func renderFrames(
        forSession sessionID: String
    ) -> [BASRenderFrame] {
        renderFrameEntries
            .filter { $0.sessionID == sessionID }
            .map { $0.frame }
    }

    public func renderFrameCount() -> Int {
        renderFrameEntries.count
    }
}
