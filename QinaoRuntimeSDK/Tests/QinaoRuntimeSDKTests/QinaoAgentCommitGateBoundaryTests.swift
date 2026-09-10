import XCTest

/// deep-audit P1-9 (2026-07-13) — boundary pin for the DECLARATIVE agent commit gate.
///
/// `QinaoAgentCommitGate.canCommit` only checks ref-PRESENCE (three non-empty strings) — it
/// verifies no signature and binds no digest. It is doctrinal shape-pin scaffolding; the real
/// tool-commit authority is `QinaoRuntime.execute` (HMAC permit/warrant/proof + digest binding).
///
/// The latent risk is that a future production path routes real commits through this weak gate
/// believing the old doc-lie ("THE single commit mouth"). This pin fails closed the moment ANY
/// production (non-test) module under Sources CALLS `canCommit`: that is the named trigger to
/// first retype the gate to accept validated, signed tokens (or route through
/// `QinaoRuntime.execute`). Until then, `canCommit` must stay test-only.
final class QinaoAgentCommitGateBoundaryTests: XCTestCase {

    private func sourcesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QinaoRuntimeSDKTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // QinaoRuntimeSDK
            .appendingPathComponent("Sources")
    }

    private func swiftFiles(under root: URL) -> [URL] {
        guard let en = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [URL] = []
        for case let url as URL in en where url.pathExtension == "swift" {
            out.append(url)
        }
        return out
    }

    /// A line "calls" canCommit if it names `canCommit(` while NOT being a comment line and NOT
    /// the declaration itself (`func canCommit`). Doc-comment references (`///`, `//`) are data.
    private func callsCanCommit(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("//") { return false }
        if t.contains("func canCommit") { return false }
        return t.contains("canCommit(")
    }

    func testNoProductionModuleCallsCanCommit() throws {
        let root = sourcesRoot()
        let files = swiftFiles(under: root)
        XCTAssertFalse(files.isEmpty, "scanner must find Source files (path drift guard)")

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (idx, line) in text.split(
                separator: "\n", omittingEmptySubsequences: false).enumerated()
            where callsCanCommit(String(line)) {
                offenders.append("\(file.lastPathComponent):\(idx + 1)  \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "P1-9: a PRODUCTION module now CALLS the declarative canCommit gate — this gate "
            + "verifies no signature/digest. Before shipping this caller, retype canCommit to "
            + "accept validated signed tokens (permit/warrant/intent + digest binding) or route "
            + "through QinaoRuntime.execute. Offenders:\n" + offenders.joined(separator: "\n"))
    }

    /// Self-check: the scanner + call-classifier actually work — the declaration in
    /// QinaoAgentProposal.swift must be RECOGNISED (as a declaration, not a call), proving the
    /// pin isn't silently green because it matched nothing / mis-parsed every line.
    func testScannerRecognisesTheDeclarationButNotAsACall() throws {
        let files = swiftFiles(under: sourcesRoot())
        let def = try XCTUnwrap(files.first { $0.lastPathComponent == "QinaoAgentProposal.swift" })
        let text = try String(contentsOf: def, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertTrue(lines.contains { $0.contains("func canCommit") },
            "the definition file must contain the canCommit declaration")
        XCTAssertFalse(lines.contains(where: callsCanCommit),
            "the declaration + its doc comments must NOT be classified as a call")
    }
}
