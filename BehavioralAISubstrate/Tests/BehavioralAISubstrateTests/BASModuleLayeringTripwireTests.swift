import XCTest
import Foundation

/// Structural-governance GATE 1 — the dependency-direction tripwire (the dep-graph the operator asked for,
/// previously unenforced). It LOCKS the clean acyclic module DAG so it can't rot: a module may only
/// `import BAS…` modules at a STRICTLY LOWER layer. An accidental upward/sideways import (e.g. a spine module
/// importing BASHostKit) fails the build.
///
/// Mechanism mirrors `BASMetalDeterminismBoundaryTests`: a single-source-of-truth map + a source grep + a
/// shared matcher used by BOTH the production test AND a negative control (so the matcher is provably
/// non-vacuous). Structure/observability only — zero runtime behavior change.
final class BASModuleLayeringTripwireTests: XCTestCase {

    /// THE single source of truth: module → layer index, derived from Package.swift's dependency DAG
    /// (each module's layer = max(dep layers) + 1, so STRICT-LESS holds by construction). Floor 0 = the
    /// non-Swift leaf targets (C / C++ / Rust-binary) that carry no Swift `import BAS…` of their own.
    /// Within the mid-band the order is real: Memory(2) < Policy(3) < Observability(4).
    static let layer: [String: Int] = [
        // 0 — non-Swift / binary / plugin / build-tooling leaves (imported, never importing a BAS runtime module)
        "BASCSystemBridge": 0,
        "BASMPSGraphExecutableCacheCxx": 0,
        "BASRustMemoryTrackerBinary": 0,
        "BASSQLSchemaGen": 0,
        "BASSQLSchemaGenCore": 0,         // SQL schema-gen core (build tooling; no BAS runtime deps)
        "BASSQLSchemaGenTool": 1,         // the tool imports BASSQLSchemaGenCore (downward)
        // 1 — foundational schema layer
        "BASRuntimeCore": 1,
        // 2 — isolated domains + transverse state base + metal substrate
        "BASLeaseLife": 2,
        "BASOrgan": 2,
        "BASSovereign": 2,
        "BASWorldPrior": 2,
        "BASMemory": 2,
        "BASMetalSubstrate": 2,
        // 3 — policy + reasoning adapters + rust bridge (depend on Memory/Organ)
        "BASPolicy": 3,
        "BASRustCoreBridge": 3,
        "BASMLXAdapter": 3,
        "BASChatCompletionsAdapter": 3,
        // 4 — observability (depends on Memory + Policy)
        "BASObservability": 4,
        // 5 — orchestration spine + evaluation (peers; neither imports the other)
        "BASOrchestration": 5,
        "BASEvaluation": 5,
        // 6 — admin
        "BASAdmin": 6,
        // 7 — apple adapters
        "BASAppleAdapters": 7,
        // 8 — host facade (top library)
        "BASHostKit": 8,
        // 9 — executable (the CLI app; consumes the facade)
        "BASBrainCLI": 9,
    ]

    // MARK: - Shared matcher (used by the production test AND the negative control)

    /// Given an importer module + its layer + one line of its source, return the BAS modules it ILLEGALLY
    /// imports (an imported BAS module at layer >= the importer's, i.e. not strictly lower). Self-imports and
    /// non-BAS imports are ignored. An imported BAS module NOT in the layer map is reported as `"?<name>"`
    /// (unclassified) so a newly-added module is caught, not silently allowed.
    static func illegalImports(of importer: String, atLayer importerLayer: Int, inSource line: String) -> [String] {
        // Only a real import STATEMENT counts — the trimmed line must START with `import` (optionally after
        // import attributes). This excludes prose/doc-comment/string mentions like `/// import BASX` or
        // `// doesn't import BASX`, which are NOT dependencies (they wouldn't compile).
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(?:@_exported |@testable |public |internal |fileprivate |private )*import\s+(BAS\w+)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = trimmed as NSString
        guard let m = re.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) else { return [] }
        let imported = ns.substring(with: m.range(at: 1))
        if imported == importer { return [] }       // self-import — ignore
        guard let importedLayer = layer[imported] else {
            return ["?\(imported)"]                  // imported a BAS module not in the map → must classify it
        }
        return importedLayer >= importerLayer ? [imported] : []   // upward or sideways-illegal
    }

    // MARK: - Helpers (derive Sources/ from this test file's path — same idiom as the determinism tripwire)

    private static func sourcesDir() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private static func swiftFiles(in dir: URL) -> [URL] {
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        var out: [URL] = []
        while let u = e?.nextObject() as? URL {
            if u.pathExtension == "swift" { out.append(u) }
        }
        return out
    }

    // MARK: - Production gate

    func testNoModuleImportsUpwardOrSideways() throws {
        let sources = Self.sourcesDir()
        let moduleDirs = (try? FileManager.default.contentsOfDirectory(
            at: sources, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("BAS") } ?? []
        XCTAssertFalse(moduleDirs.isEmpty, "no Sources/BAS* module dirs found — path wrong?")

        var violations: [String] = []
        var scanned = 0
        for dir in moduleDirs {
            let module = dir.lastPathComponent
            // COMPLETENESS: every BAS source-module dir must be classified, or a new module slipped in unranked.
            guard let importerLayer = Self.layer[module] else {
                violations.append("UNCLASSIFIED module Sources/\(module) — add it to `layer` with its DAG level")
                continue
            }
            scanned += 1
            for file in Self.swiftFiles(in: dir) {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                    let bad = Self.illegalImports(of: module, atLayer: importerLayer, inSource: String(line))
                    for b in bad {
                        violations.append(
                            "\(module) (L\(importerLayer)) → \(b) "
                            + "[\(file.lastPathComponent)]")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "MODULE-LAYERING VIOLATION (dependency direction must point strictly DOWN the DAG):\n"
            + violations.sorted().joined(separator: "\n"))
        XCTAssertGreaterThan(scanned, 10, "expected to scan the package's BAS modules; scanned \(scanned)")
    }

    // MARK: - Negative control (proves the matcher actually catches an upward import)

    func testTripwireActuallyCatchesAnUpwardImport() {
        // BASRuntimeCore (L1) illegally importing BASHostKit (L8) must be flagged.
        let bad = Self.illegalImports(
            of: "BASRuntimeCore", atLayer: Self.layer["BASRuntimeCore"]!,
            inSource: "import BASHostKit")
        XCTAssertEqual(bad, ["BASHostKit"],
            "the matcher must flag an upward import — else the production gate is vacuous")

        // A legal downward import (BASHostKit L8 → BASRuntimeCore L1) must NOT be flagged.
        let ok = Self.illegalImports(
            of: "BASHostKit", atLayer: Self.layer["BASHostKit"]!,
            inSource: "@_exported import BASRuntimeCore")
        XCTAssertTrue(ok.isEmpty, "a legal downward import must not be flagged (no false positive)")

        // A sideways/peer import (BASEvaluation L5 → BASOrchestration L5) must be flagged (strict-less).
        let peer = Self.illegalImports(
            of: "BASEvaluation", atLayer: Self.layer["BASEvaluation"]!,
            inSource: "import BASOrchestration")
        XCTAssertEqual(peer, ["BASOrchestration"], "same-layer import must be flagged (strict-less rule)")
    }
}
