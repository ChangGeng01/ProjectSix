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
    private static let modelRuntimeModules = [
        "CoreML", "FoundationModels", "CoreAI", "MLX", "Tokenizers", "NaturalLanguage",
    ]

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BehavioralAISubstrateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // BehavioralAISubstrate
    }

    /// Extract one target's dependency block from Package.swift.
    ///
    /// deep-audit HIGH-2 (2026-07-13): the prior parser cut at the FIRST `]`, which in a
    /// real dependency array closes a NESTED array (e.g. `.when(platforms: [.iOS, .macOS])`)
    /// long before the array's own close — so the tail of the dep list (where BASOrgan sits,
    /// the natural append site) never entered the captured block and a model dep appended
    /// there slipped the exclusion check silently (green-by-luck). Now: anchor on
    /// `dependencies: [` and BALANCED-BRACKET match — walk counting `[`/`]`, stop at the `]`
    /// that returns depth to 0. Nested arrays are transparently included.
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
                guard let depsOpen = tail.range(of: "dependencies: [") else {
                    searchStart = nameRange.upperBound
                    continue
                }
                // balanced-bracket scan starting just after the opening '['.
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
        throw XCTSkip("target \(target) not found")
    }

    func testHostKitManifestExcludesModelAdapterModules() throws {
        let manifest = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8)
        let deps = try dependencyBlock(of: "BASHostKit", in: manifest)
        // deep-audit HIGH-2 anti-truncation guard: the captured block MUST reach the last
        // real dep, or a tail-appended model dep would slip the exclusion below unseen.
        XCTAssertTrue(deps.contains("\"BASOrgan\""),
            "parser truncated the dep block before the tail — the exclusion check below "
            + "would be blind to a model dep appended at the natural (tail) site")
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
        // deep-audit HIGH-2 compounding fix: check ALL THREE first-party model-adapter
        // modules (a first-party `import BASMLXAdapter` transitively re-links MLX), and
        // via the robust matcher below that sees attributed/qualified import forms.
        let dir = packageRoot.appendingPathComponent("Sources/BASHostKit")
        // deep-audit L-4 (2026-07-13): RECURSIVE — SwiftPM globs .swift recursively, so a
        // future Sources/BASHostKit/SubDir/Foo.swift with a model import must not escape.
        let files = Self.swiftFilesRecursive(under: dir)
        XCTAssertGreaterThan(files.count, 100, "sanity: HostKit sources present")
        var offenders: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.split(separator: "\n") {
                for module in Self.modelModules
                where Self.lineImportsModule(String(line), module) {
                    offenders.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "BASHostKit sources import a model-adapter module: \(offenders)")
    }

    /// deep-audit MEDIUM-2 (2026-07-13): robust import matcher. Strips leading attributes
    /// (`@_exported`, `@preconcurrency`, `@testable`) and an optional decl-kind
    /// (`import class Foo.Bar`), then matches the module as the first path component — so
    /// `@_exported import CoreML`, `@preconcurrency import FoundationModels`,
    /// `import class CoreML.MLModel`, and `import MLX.Something` are ALL caught, not just
    /// bare `import CoreML`.
    static func lineImportsModule(_ rawLine: String, _ module: String) -> Bool {
        var t = rawLine.trimmingCharacters(in: .whitespaces)
        // strip any leading @attributes (possibly several)
        while t.hasPrefix("@") {
            guard let sp = t.firstIndex(of: " ") else { return false }
            t = String(t[t.index(after: sp)...]).trimmingCharacters(in: .whitespaces)
        }
        guard t.hasPrefix("import ") else { return false }
        var rest = String(t.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
        // optional decl-kind: import class/struct/enum/protocol/func/var/let/typealias
        for kind in ["class ", "struct ", "enum ", "protocol ", "func ", "var ", "let ", "typealias "]
        where rest.hasPrefix(kind) {
            rest = String(rest.dropFirst(kind.count)).trimmingCharacters(in: .whitespaces)
        }
        // module is the first dotted path component; strip trailing comment/space
        let firstComponent = rest.split(whereSeparator: { $0 == "." || $0 == " " }).first.map(String.init) ?? rest
        return firstComponent == module
    }

    func testLifecycleKitSourcesHaveZeroModelRuntimeImports() throws {
        try assertNoModelRuntimeImports(
            in: "Sources/BASAppleLifecycleKit", minFiles: 10,
            label: "the PURE lifecycle kit")
    }

    /// charter continuation 2026-07-13 (residual #4): the T4 cut removed the model-ADAPTER
    /// module edge, but the boundary claim "BASHostKit invokes no model runtime directly"
    /// was only manifest-pinned, not source-pinned. After T4 it is TRUE (the adjudicator's
    /// embedder is edge-injected, the NLI bridge + MLModel Chenglu overload moved out), so
    /// pin it: BASHostKit sources import NO model runtime (CoreML/FoundationModels/CoreAI/
    /// MLX/Tokenizers) — not even platform-gated. A future re-introduction reds here.
    func testHostKitSourcesHaveZeroModelRuntimeImports() throws {
        try assertNoModelRuntimeImports(
            in: "Sources/BASHostKit", minFiles: 100, label: "the HostKit core umbrella")
    }

    private func assertNoModelRuntimeImports(
        in relativeDir: String, minFiles: Int, label: String
    ) throws {
        let dir = packageRoot.appendingPathComponent(relativeDir)
        let files = Self.swiftFilesRecursive(under: dir)   // deep-audit L-4: recursive
        XCTAssertGreaterThan(files.count, minFiles, "sanity: \(label) sources present")
        var offenders: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.split(separator: "\n") {
                for imp in Self.modelRuntimeModules
                where Self.lineImportsModule(String(line), imp) {
                    offenders.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "model-runtime imports inside \(label): \(offenders)")
    }

    /// deep-audit MEDIUM-2: the matcher must catch attributed / decl-kind / submodule
    /// forms, not just bare `import X`, or a future attributed reintroduction slips both
    /// this pin and the facade guard.
    func testImportMatcherCatchesAttributedAndQualifiedForms() {
        let hits = [
            "import CoreML",
            "  import CoreML",
            "@_exported import CoreML",
            "@preconcurrency import FoundationModels",
            "@_exported @preconcurrency import CoreML",
            "import class CoreML.MLModel",
            "import CoreML.MLModel",
            "import MLX  // comment",
        ]
        for line in hits {
            let m = line.contains("FoundationModels") ? "FoundationModels"
                : line.contains("MLX") ? "MLX" : "CoreML"
            XCTAssertTrue(Self.lineImportsModule(line, m),
                "matcher must catch: \(line)")
        }
        // must NOT false-positive on comments or a different module
        XCTAssertFalse(Self.lineImportsModule("// import CoreML in a comment", "CoreML"))
        XCTAssertFalse(Self.lineImportsModule("import CoreMLTools", "CoreML"),
            "prefix-only must not match (CoreMLTools != CoreML)")
        XCTAssertFalse(Self.lineImportsModule("import Foundation", "CoreML"))
    }

    /// deep-audit L-4: recursively enumerate .swift files (matches SwiftPM's glob).
    static func swiftFilesRecursive(under dir: URL) -> [URL] {
        guard let en = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: nil) else { return [] }
        return en.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
