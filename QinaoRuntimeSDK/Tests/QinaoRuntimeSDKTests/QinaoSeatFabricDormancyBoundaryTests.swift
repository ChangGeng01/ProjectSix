import XCTest

/// deep-audit CBNF-1 (2026-07-13) — boundary pin for the DORMANT seat-fabric propose→commit lane.
///
/// The QinaoSeats agent fabric (QinaoStateGraphBus / QinaoSeatResidencyManager /
/// QinaoSeatProposingProtocol+QinaoAgentProposalRegistry / QinaoSpeculativeCouncil) is test-only
/// scaffolding — no production path drives it; live seats emit `SeatVerdict` via `contribute`.
/// The lane's entry point is `QinaoAgentProposalRegistry.dispatchProposals`. The latent risk is
/// a future production path wiring this lane onto the sovereign spine WITHOUT first retyping its
/// commit path to the signed-token gate (see the P1-9 declarative-gate finding).
///
/// This pin fails closed the moment ANY production (non-test) module under Sources CALLS
/// `dispatchProposals`: that is the named trigger to (a) harden the commit path and (b) flip the
/// DORMANT header notes to "live". Until then the fabric must stay test-only.
final class QinaoSeatFabricDormancyBoundaryTests: XCTestCase {

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
        for case let url as URL in en where url.pathExtension == "swift" { out.append(url) }
        return out
    }

    /// A line "calls" dispatchProposals if it names `dispatchProposals(` while NOT being a
    /// comment and NOT the declaration itself. Doc-comment references (`///`, `//`) are data.
    private func callsDispatch(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("//") { return false }
        if t.contains("func dispatchProposals") { return false }
        return t.contains("dispatchProposals(")
    }

    func testNoProductionModuleWiresTheSeatFabric() throws {
        let files = swiftFiles(under: sourcesRoot())
        XCTAssertFalse(files.isEmpty, "scanner must find Source files (path drift guard)")

        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (idx, line) in text.split(
                separator: "\n", omittingEmptySubsequences: false).enumerated()
            where callsDispatch(String(line)) {
                offenders.append("\(file.lastPathComponent):\(idx + 1)  \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "CBNF-1: a PRODUCTION module now WIRES the dormant seat-fabric lane (dispatchProposals). "
            + "Before shipping this, retype the fabric's commit path to the signed-token gate "
            + "(P1-9) and flip the DORMANT header notes to live. Offenders:\n"
            + offenders.joined(separator: "\n"))
    }

    /// Self-check: the scanner + classifier actually work — the declaration in
    /// QinaoSeatProposingProtocol.swift must be RECOGNISED (as a declaration, not a call).
    func testScannerSeesTheDeclarationButNotAsACall() throws {
        let files = swiftFiles(under: sourcesRoot())
        let def = try XCTUnwrap(files.first { $0.lastPathComponent == "QinaoSeatProposingProtocol.swift" })
        let lines = try String(contentsOf: def, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertTrue(lines.contains { $0.contains("func dispatchProposals") },
            "the definition file must contain the dispatchProposals declaration")
        XCTAssertFalse(lines.contains(where: callsDispatch),
            "the declaration + its doc comments must NOT be classified as a call")
    }
}
