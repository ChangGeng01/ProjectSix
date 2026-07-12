#if os(macOS)
import XCTest

/// Frame-budget lint for the runTurn debug stack (the cooperative-pool SIGBUS class).
///
/// History: runTurn was a single 129,792-byte -Onone frame (llvm-objdump-measured) — with the
/// pre-box 12,200-byte turn result it put the turn pipeline at ~550KB, over swift-testing's
/// 512KB cooperative threads. 2026-07-12: the body is split into six NAMED LOCAL FUNCTIONS
/// (memoryDeliberate / riskA / riskB / renderA / renderB / assemble — an immediately-applied
/// closure literal does NOT work: SILGen inlines it, measured), so the debug peak is
/// main-residual + the largest single stage: 20,672 + 35,632 = 56,304 B at pin time.
///
/// This test re-measures the built object with llvm-objdump and reds if the peak regresses
/// past the budget — the mechanical guard that lets turn-driving swift-testing suites run
/// main-actor-unpinned on the cooperative pool.
final class BASRunTurnFrameBudgetTests: XCTestCase {

    /// peak budget = pin-time 56,304 + ~40% headroom. A red here means a stage grew a huge
    /// -Onone frame back — split the stage further, don't raise the budget casually.
    private static let peakBudgetBytes = 80_000
    private static let stageNames = ["memoryDeliberateStage", "riskStageA", "riskStageB",
                                     "renderStageA", "renderStageB", "assembleStage"]

    func testRunTurnDebugPeakFrameStaysUnderBudget() throws {
        // package root from this file's path; native-SPM object layout (stable toolchain / CI).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let obj = root.appendingPathComponent(
            ".build/arm64-apple-macosx/debug/BASHostKit.build/EBrainRuntimeCoordinator+RunTurn.swift.o")
        guard FileManager.default.fileExists(atPath: obj.path) else {
            throw XCTSkip("native-SPM object not present (swiftbuild layout or fresh checkout) — host lint")
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["llvm-objdump", "-d", obj.path]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw XCTSkip("llvm-objdump unavailable") }
        let dis = String(decoding: data, as: UTF8.self)

        // sum `sub sp, sp, #imm(, lsl #12)?` per symbol
        var frames: [String: Int] = [:]
        var current: String?
        let symbol = try NSRegularExpression(pattern: "^[0-9a-f]+ <(.+)>:$")
        let subSp = try NSRegularExpression(pattern: "sub\\s+sp, sp, #0x([0-9a-f]+)(, lsl #12)?")
        for line in dis.split(separator: "\n", omittingEmptySubsequences: false) {
            let l = String(line)
            let range = NSRange(l.startIndex..., in: l)
            if let m = symbol.firstMatch(in: l, range: range), let r = Range(m.range(at: 1), in: l) {
                current = String(l[r]); frames[current!] = 0; continue
            }
            guard let cur = current,
                  let m = subSp.firstMatch(in: l, range: range),
                  let r = Range(m.range(at: 1), in: l),
                  var v = Int(l[r], radix: 16) else { continue }
            if m.range(at: 2).location != NSNotFound { v <<= 12 }
            frames[cur, default: 0] += v
        }

        // main = the runTurn body (addr-0 label ltmp0 in this object, or the mangled symbol)
        let main = max(
            frames["ltmp0"] ?? 0,
            frames.filter { $0.key.contains("V7runTurnyAA") && !$0.key.contains("L_") }
                .map(\.value).max() ?? 0)
        var stageMax = 0
        var report: [String] = ["runTurn-main: \(main) B"]
        for stage in Self.stageNames {
            let sz = frames.filter { $0.key.contains(stage) }.map(\.value).max() ?? 0
            XCTAssertGreaterThan(sz, 0,
                "stage function '\(stage)' not found in the object — the stage split was undone?")
            stageMax = max(stageMax, sz)
            report.append("\(stage): \(sz) B")
        }
        let peak = main + stageMax
        report.append("PEAK: \(peak) B (budget \(Self.peakBudgetBytes))")
        XCTAssertLessThanOrEqual(peak, Self.peakBudgetBytes,
            "runTurn debug stack peak regressed — split the offending stage, don't ride the budget:\n"
            + report.joined(separator: "\n"))
    }
}
#endif

// MARK: - stage-contract naming lint (context-IR step 1)

/// 2026-07-12 operator order ("阶段合同具名化"): runTurn's stage functions must return NAMED
/// context types (BAS*StageContext), not ad-hoc tuples — the tuple contracts were the measured
/// signature of distributed context engineering (9/4/10/16/12 anonymous values). A red here
/// means someone added a stage returning a bare tuple: name its contract instead.
extension BASRunTurnFrameBudgetTests {
    func testStageContractsAreNamedTypesNotTuples() throws {
        let src = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift"),
            encoding: .utf8)
        let offenders = src.split(separator: "\n").enumerated().filter { _, line in
            line.contains("Stage") && line.contains("func ") && line.contains("-> (")
        }
        XCTAssertTrue(offenders.isEmpty,
            "stage functions returning anonymous tuples (name the contract as a BAS*StageContext):\n"
            + offenders.map { "line \($0.0 + 1): \($0.1.trimmingCharacters(in: .whitespaces).prefix(90))" }
                .joined(separator: "\n"))
        for ty in ["BASMemoryDeliberateStageContext", "BASRiskBindStageContext",
                   "BASRiskEscalateStageContext", "BASRenderVerdictStageContext",
                   "BASAuditProjectionStageContext"] {
            XCTAssertTrue(src.contains(ty), "stage contract type \(ty) not wired into runTurn")
        }
    }
}
