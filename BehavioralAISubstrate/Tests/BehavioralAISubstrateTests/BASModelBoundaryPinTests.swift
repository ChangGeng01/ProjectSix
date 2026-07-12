import XCTest

/// charter audit 2026-07-12 T4 — MECHANICAL pin of the LLM-outside cut (substrate side).
///
/// The audit found the old boundary held "by convention, not by link topology": BASHostKit
/// hard-depended on AND @_exported-imported BASAppleAdapters (the FoundationModels-linking
/// module), so every core-umbrella consumer transitively linked the LLM adapter, and the
/// SDK-side pin was blind to the path. This pin makes the cut structural:
///  1. BASHostKit's manifest deps exclude every model-adapter module.
///  2. BASHostKit sources never import BASAppleAdapters (re-export or plain).
///  3. BASAppleLifecycleKit (the pure kit BASHostKit now rides) contains ZERO model-runtime
///     imports — not even platform-gated ones (gated model code in the pure kit would be
///     model code in the pure kit).
final class BASModelBoundaryPinTests: XCTestCase {

    private static let modelModules = [
        "BASAppleAdapters", "BASMLXAdapter", "BASChatCompletionsAdapter",
    ]
    private static let modelRuntimeImports = [
        "import CoreML", "import FoundationModels", "import CoreAI",
        "import MLX", "import Tokenizers",
    ]

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BehavioralAISubstrateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // BehavioralAISubstrate
    }

    /// Extract one target's dependency block from Package.swift (anchor skips .library
    /// product declarations — same parser shape as the SDK-side QinaoBoundaryPinTests).
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
                guard let end = tail.range(of: "]") else { return String(tail.prefix(4_000)) }
                return String(tail[..<end.lowerBound])
            }
            searchStart = nameRange.upperBound
        }
        throw XCTSkip("target \(target) not found")
    }

    func testHostKitManifestExcludesModelAdapterModules() throws {
        let manifest = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8)
        let deps = try dependencyBlock(of: "BASHostKit", in: manifest)
        for module in Self.modelModules {
            XCTAssertFalse(deps.contains("\"\(module)\""),
                "BOUNDARY VIOLATION: BASHostKit depends on model module \(module) — "
                + "the core host umbrella must stay LLM-link-free (charter T4)")
        }
        XCTAssertTrue(deps.contains("\"BASAppleLifecycleKit\""),
            "parser self-check: BASHostKit must ride the pure lifecycle kit")
    }

    func testLifecycleKitManifestExcludesModelModules() throws {
        let manifest = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8)
        let deps = try dependencyBlock(of: "BASAppleLifecycleKit", in: manifest)
        for module in Self.modelModules {
            XCTAssertFalse(deps.contains("\"\(module)\""),
                "BASAppleLifecycleKit must not depend on \(module)")
        }
    }

    func testHostKitSourcesNeverImportTheAdapterModule() throws {
        let dir = packageRoot.appendingPathComponent("Sources/BASHostKit")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 100, "sanity: HostKit sources present")
        var offenders: [String] = []
        for f in files {
            let text = try String(
                contentsOf: dir.appendingPathComponent(f), encoding: .utf8)
            for line in text.split(separator: "\n")
            where line.trimmingCharacters(in: .whitespaces)
                .hasPrefix("import BASAppleAdapters")
                || line.trimmingCharacters(in: .whitespaces)
                .hasPrefix("@_exported import BASAppleAdapters")
            {
                offenders.append(f)
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "BASHostKit sources import the model-adapter module: \(offenders)")
    }

    func testLifecycleKitSourcesHaveZeroModelRuntimeImports() throws {
        let dir = packageRoot.appendingPathComponent("Sources/BASAppleLifecycleKit")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 10, "sanity: kit sources present")
        var offenders: [String] = []
        for f in files {
            let text = try String(
                contentsOf: dir.appendingPathComponent(f), encoding: .utf8)
            for imp in Self.modelRuntimeImports where text.contains(imp) {
                offenders.append("\(f): \(imp)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "model-runtime imports inside the PURE lifecycle kit: \(offenders)")
    }
}
