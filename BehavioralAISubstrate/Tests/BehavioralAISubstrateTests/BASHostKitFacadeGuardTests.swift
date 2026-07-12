import XCTest
import Foundation

/// Structural-governance GATE 2 — keep BASHostKit a COMPOSITION facade, not a business-logic sink.
/// Two enforced contracts, both observability-only (zero runtime change):
///   (a) the `@_exported import` re-export surface is PINNED — adding a 9th fails until consciously updated;
///   (b) a business-logic LEAK CAP — the known god-files may shrink (the deferred extraction) but not grow,
///       and NO NEW >800-LOC business-logic file may appear, and the total file count stays in a band.
/// This guards against MORE leakage without forcing the (deferred, R1-gated) extraction.
final class BASHostKitFacadeGuardTests: XCTestCase {

    private static func hostKitDir() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BASHostKit")
    }

    private static func swiftFiles() -> [URL] {
        let e = FileManager.default.enumerator(at: hostKitDir(), includingPropertiesForKeys: nil)
        var out: [URL] = []
        while let u = e?.nextObject() as? URL {
            if u.pathExtension == "swift" { out.append(u) }
        }
        return out
    }

    private static func loc(_ url: URL) -> Int {
        guard let t = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        return t.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    // MARK: - (a) Re-export surface PIN

    /// Extract the distinct set of `@_exported import BAS…` modules from source lines (anchored — ignores
    /// `// @_exported import …` prose). Shared by the production test + the negative control.
    static func exportedBASModules(inLines lines: [String]) -> Set<String> {
        let re = try! NSRegularExpression(pattern: #"^@_exported\s+import\s+(BAS\w+)"#)
        var set: Set<String> = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let ns = line as NSString
            if let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                set.insert(ns.substring(with: m.range(at: 1)))
            }
        }
        return set
    }

    /// The pinned facade surface. `import BASHostKit` transitively re-exports exactly these 8 — by design
    /// (one-line host integration), but it MUST be a conscious set. Growing it blurs boundaries → update here
    /// only with intent.
    static let pinnedExports: Set<String> = [
        "BASAdmin", "BASAppleAdapters", "BASEvaluation", "BASMemory",
        "BASObservability", "BASOrchestration", "BASPolicy", "BASRuntimeCore",
    ]

    func testReExportSurfaceIsPinned() {
        var lines: [String] = []
        for f in Self.swiftFiles() {
            if let t = try? String(contentsOf: f, encoding: .utf8) {
                lines += t.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            }
        }
        let actual = Self.exportedBASModules(inLines: lines)
        XCTAssertEqual(
            actual, Self.pinnedExports,
            "BASHostKit @_exported surface changed. Added: \(actual.subtracting(Self.pinnedExports)); "
            + "Removed: \(Self.pinnedExports.subtracting(actual)). A facade re-export is a deliberate "
            + "boundary decision — update `pinnedExports` only with intent (don't let the facade grow).")
    }

    func testExportSetMatcherCatchesANewReExport() {
        // Negative control: a new re-export IS detected; a commented one is NOT (no false positive).
        XCTAssertTrue(
            Self.exportedBASModules(inLines: ["@_exported import BASNewLeak"]).contains("BASNewLeak"))
        XCTAssertTrue(
            Self.exportedBASModules(inLines: ["// @_exported import BASCommented"]).isEmpty,
            "a commented re-export must NOT count (anchored matcher)")
    }

    // MARK: - (b) Business-logic LEAK CAP

    /// Known large files (LOC ceilings = current + ~8-10% headroom: they may SHRINK as the deferred extraction
    /// moves logic DOWN, but must not GROW). NONE are the ch879-pinned `BASCognitiveBrain*` family (those are
    /// <800 LOC + tracked by BASChapter879BrainLOCTrajectoryAuditTests — no double-pin).
    static let knownLargeFileCeilings: [String: Int] = [
        "HostSynthesisPolicyCore.swift": 2350,
        "EBrainRuntimeCoordinator+RunTurn.swift": 2350,
        "EBrainRuntimeCoordinator+SovereignCommit.swift": 1925,
        "BASAuditObservationProjections.swift": 1665,
        // 2026-07-12 CoW-box extraction: 1496→707 (main file keeps struct+Storage+fields+all-fields
        // init; convenience inits + Codable extracted to +BundleInits/+BundleInitsLegacy/+Codable).
        // Re-pinned TIGHT at current+~6% so the ratchet keeps teeth (~5 fields of headroom: a new
        // field costs ~9 LOC here — Storage var+init arg+assign+clone+equals+computed get/set).
        "EBrainTurnResult.swift": 750,
        "HostRuntimeCore.swift": 1365,
        // 2026-07-11 reconciliation: grew 1055→1123 across the 07-09 audit fixes (M-k F1
        // ledger-locality + the BAS_TURN_SERIAL per-key in-flight gate — both commit-traceable,
        // deliberate safety work, not drift). Re-pinned TIGHT at current+7 so the ratchet keeps teeth.
        "BASTurnRuntimeEngine.swift": 1130,
        "EBrainConsoleSupport.swift": 960,
        "BASCognitiveOSConvenience.swift": 895,
        "HostKitCore.swift": 890,
        "EBrainHostRuntime+TriSelfService.swift": 885,
        // 2026-07-11 reconciliation: crossed 800 on 07-09 (hostkit-rest HIGH-2 — the .all-tier
        // watcher effective-inputs fix, 7321781f1). Genuine composition (fabric seat wiring), but
        // flagged for the deferred extraction list. Pinned TIGHT at current+8.
        "BASAgentFabricHostPipeline.swift": 815,
        // 2026-07-12 context-IR step 4: runTurn's stage bodies moved VERBATIM into stage-method
        // files (declared read surfaces); two carry two stages each. Pinned TIGHT at current+~8
        // so the ratchet keeps teeth — new logic goes in lower modules, not here.
        "EBrainRuntimeCoordinator+RunTurnStagesEscalateRender.swift": 815,
        "EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift": 880,
    ]

    func testNoNewLargeFileAndKnownGodFilesDoNotGrow() {
        var violations: [String] = []
        for f in Self.swiftFiles() {
            let name = f.lastPathComponent
            let lines = Self.loc(f)
            if let ceiling = Self.knownLargeFileCeilings[name] {
                if lines > ceiling {
                    violations.append("\(name) GREW to \(lines) LOC (ceiling \(ceiling)) — extract DOWN, don't grow")
                }
            } else if lines > 800 {
                violations.append(
                    "NEW large HostKit file \(name) (\(lines) LOC > 800) — HostKit should COMPOSE, not absorb "
                    + "business logic. Put domain logic in a lower module, or (if truly composition) add it to "
                    + "knownLargeFileCeilings with justification.")
            }
        }
        XCTAssertTrue(violations.isEmpty,
            "HostKit business-logic LEAK CAP:\n" + violations.sorted().joined(separator: "\n"))
    }

    func testHostKitFileCountStaysInBand() {
        // 255 today. A band (not a hard pin) — a big influx of new HostKit files signals leaked logic.
        // 2026-07-12 deliberate raise 285→288: the EBrainTurnResult CoW-box extraction split the
        // 1919-LOC god file into main + BundleInits(×2) + Codable (net +3) — pure structural
        // extraction of an EXISTING type demanded by the LOC leak-cap above, zero new logic.
        // 2026-07-12 deliberate raise 288→292: context-IR arc (operator-ordered) — StageContexts +
        // TurnResponse + TurnContextCompiler + 3 stage-method files (verbatim-moved runTurn bodies),
        // minus the deleted BundleInitsLegacy. Structural extractions, zero new business logic.
        // 2026-07-12 deliberate raise 292→294: mirror-lane charter M1-M3 (operator ruling ① —
        // "汇合管线落 BASHostKit": convergence is EXPLICITLY HostKit property) — Convergence
        // (envelope + deterministic disposer) + LedgerIngest (verify-then-append gate).
        let count = Self.swiftFiles().count
        XCTAssertLessThanOrEqual(count, 294,
            "BASHostKit grew to \(count) files (band 294). New files likely belong in a lower module "
            + "(composition stays small) — or raise the band deliberately.")
        XCTAssertGreaterThan(count, 100, "sanity: expected to find the HostKit sources; found \(count)")
    }
}
