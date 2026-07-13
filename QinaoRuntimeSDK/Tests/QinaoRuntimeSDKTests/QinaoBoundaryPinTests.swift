import XCTest

/// integration S2 (2026-07-12) — MECHANICAL pin of the clean LLM boundary.
///
/// Charter rule 3: the integrated assembly's modules must never link the LLM endpoint
/// modules (QinaoAppleFoundation / QinaoMLX). This test parses Package.swift's actual
/// target blocks (structure probed, not comments trusted — fossil-guard style): if
/// someone wires an LLM module into an IN-boundary target, this reds.
final class QinaoBoundaryPinTests: XCTestCase {

    /// Modules INSIDE the boundary (the integrated LLM-free host assembly).
    private static let inBoundaryTargets = [
        "QinaoDefaults", "QinaoRuntime", "QinaoSovereign", "QinaoMemory",
        "QinaoRisk", "QinaoHost", "QinaoLoop", "QinaoSeats", "QinaoLoopSeats",
        "QinaoWorldPrior",
    ]

    /// Modules OUTSIDE the boundary (LLM endpoints — data-only crossing).
    /// charter audit 2026-07-12 T4 upgrade: the audit proved this pin was BLIND to the
    /// real leak path (BAS-side products) — QinaoRuntime linked FoundationModels via
    /// BASHostKit→BASAppleAdapters while this pin stayed green. The BAS-side cut
    /// (BASModelBoundaryPinTests) removed that edge; THIS list now also bans declaring
    /// the BAS model-adapter products directly in any in-boundary target.
    private static let llmModules = [
        "QinaoAppleFoundation", "QinaoMLX",
        "BASAppleAdapters", "BASMLXAdapter", "BASChatCompletionsAdapter",
    ]

    /// Extract one target's dependency block from Package.swift text.
    ///
    /// Anchors on a `name: "<target>"` occurrence PRECEDED by `.target(` (skipping the
    /// `.library(name:...)` product declarations that share the same name), then takes
    /// the text until the dependencies array closes.
    private func dependencyBlock(
        of target: String, in manifest: String
    ) throws -> String {
        var searchStart = manifest.startIndex
        while let nameRange = manifest.range(
            of: "name: \"\(target)\"", range: searchStart..<manifest.endIndex)
        {
            let contextStart = manifest.index(
                nameRange.lowerBound, offsetBy: -60,
                limitedBy: manifest.startIndex) ?? manifest.startIndex
            let context = manifest[contextStart..<nameRange.lowerBound]
            if context.contains(".target(") || context.contains(".executableTarget(") {
                let tail = manifest[nameRange.upperBound...]
                // deep-audit P2-21(d) (2026-07-13): the old `tail.range(of: "]),") ?? "])"`
                // cut at the FIRST bracket-close, which for a target whose dependencies
                // contain a nested array (e.g. `.product(... , condition: .when(platforms: [.iOS]))`
                // or a trailing `swiftSettings: [...]`) closes the WRONG bracket and silently
                // truncates the scanned block — the same green-by-luck defect fixed in
                // BASModelBoundaryPinTests. Anchor on `dependencies: [` and balance-match.
                guard let depsOpen = tail.range(of: "dependencies: [") else {
                    searchStart = nameRange.upperBound
                    continue
                }
                var depth = 1
                var i = depsOpen.upperBound
                let bodyStart = i
                while i < tail.endIndex {
                    let c = tail[i]
                    if c == "[" { depth += 1 }
                    else if c == "]" {
                        depth -= 1
                        if depth == 0 { return String(tail[bodyStart..<i]) }
                    }
                    i = tail.index(after: i)
                }
                return String(tail[bodyStart...])
            }
            searchStart = nameRange.upperBound
        }
        // deep-audit P2-21(c): a required target the manifest no longer matches must FAIL,
        // not XCTSkip into a false green.
        struct RequiredTargetNotFound: Error, CustomStringConvertible {
            let target: String
            var description: String {
                "boundary-pin target '\(target)' not found in Package.swift — manifest drift"
            }
        }
        throw RequiredTargetNotFound(target: target)
    }

    func testInBoundaryTargetsNeverDependOnLLMModules() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QinaoRuntimeSDKTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // QinaoRuntimeSDK
            .appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        for target in Self.inBoundaryTargets {
            let deps = try dependencyBlock(of: target, in: manifest)
            for llm in Self.llmModules {
                XCTAssertFalse(
                    deps.contains("\"\(llm)\""),
                    "BOUNDARY VIOLATION: in-boundary target \(target) depends on LLM "
                    + "module \(llm) — the integrated host must stay LLM-free "
                    + "(charter: Docs/QINAO_INTEGRATION_CHARTER_2026-07-12.md)")
            }
        }
    }

    /// Self-check: the parser actually sees dependencies (guards against the pin
    /// silently passing because the block extraction matched nothing).
    func testPinParserSeesRealDependencies() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
        let deps = try dependencyBlock(of: "QinaoDefaults", in: manifest)
        XCTAssertTrue(deps.contains("\"QinaoRuntime\""),
            "parser must see QinaoDefaults' real dependency list (it wires the assembly)")
    }
}
