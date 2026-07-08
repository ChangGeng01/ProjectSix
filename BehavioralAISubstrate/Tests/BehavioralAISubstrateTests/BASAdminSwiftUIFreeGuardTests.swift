import XCTest

/// audit M-o MED-2 — BASAdmin is substrate-core. A SwiftUI view
/// (`BASConsoleView`) lived inside it, so every HEADLESS host that depends on
/// BASAdmin transitively (BASBrainCLI, BASJournalCLI via BASHostKit) was
/// forced to link SwiftUI — a dependency the module boundary couldn't see.
/// The view moved to a dedicated `BASAdminUI` target. These guards fail if
/// SwiftUI is ever re-introduced into the SwiftUI-free core modules.
final class BASAdminSwiftUIFreeGuardTests: XCTestCase {

    private func moduleSourceDir(_ module: String) -> URL {
        // #filePath = <repo>/Tests/BehavioralAISubstrateTests/<thisfile>.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BehavioralAISubstrateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Sources/\(module)")
    }

    private func swiftUIImporters(in module: String) throws -> [String] {
        let dir = moduleSourceDir(module)
        let fm = FileManager.default
        // The guard is only meaningful if the directory actually resolves.
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: dir.path, isDirectory: &isDir) && isDir.boolValue,
                      "could not locate Sources/\(module) at \(dir.path)")
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var offenders: [String] = []
        for case let url as URL in en where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("import SwiftUI") {
                offenders.append(url.lastPathComponent)
            }
        }
        return offenders.sorted()
    }

    func testBASAdminCoreHasNoSwiftUI() throws {
        XCTAssertEqual(try swiftUIImporters(in: "BASAdmin"), [],
            "BASAdmin is SwiftUI-free core — the console view belongs in BASAdminUI (audit M-o MED-2)")
    }

    func testBASHostKitHasNoSwiftUI() throws {
        XCTAssertEqual(try swiftUIImporters(in: "BASHostKit"), [],
            "BASHostKit must not link SwiftUI — headless hosts depend on it (audit M-o MED-2)")
    }

    /// Positive control: the split actually put the view SOMEWHERE — BASAdminUI
    /// is expected to import SwiftUI (guards against a mis-extraction that
    /// silently dropped the view).
    func testBASAdminUIDoesCarrySwiftUI() throws {
        XCTAssertFalse(try swiftUIImporters(in: "BASAdminUI").isEmpty,
            "BASAdminUI must hold the SwiftUI console view after the split")
    }
}
