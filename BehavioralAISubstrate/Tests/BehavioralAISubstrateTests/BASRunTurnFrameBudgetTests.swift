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
        // step 4 moved the stage methods into three sibling files — scan all four objects
        let objDir = root.appendingPathComponent(".build/arm64-apple-macosx/debug/BASHostKit.build")
        let objNames = ["EBrainRuntimeCoordinator+RunTurn.swift.o",
                        "EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift.o",
                        "EBrainRuntimeCoordinator+RunTurnStagesEscalateRender.swift.o",
                        "EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift.o"]
        var dis = ""
        for name in objNames {
            let obj = objDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: obj.path) else {
                throw XCTSkip("native-SPM object \(name) not present (swiftbuild layout or fresh checkout)")
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["llvm-objdump", "-d", obj.path]
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw XCTSkip("llvm-objdump unavailable") }
            // prefix each symbol header with its object so per-object attribution survives
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                if line.hasSuffix(">:"), line.contains(" <") {
                    dis += line.replacingOccurrences(of: " <", with: " <\(name)|") + "\n"
                } else {
                    dis += line + "\n"
                }
            }
        }

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

        // Attribution note: each object's FIRST function is emitted under the local label
        // ltmp0 (its mangled name doesn't head the disassembly), and name-matching then hits
        // small thunks — measured 2026-07-12: riskStageB name-match said 304B while its real
        // body (ltmp0 of its object) was 28,432B. Robust budget: peak = the RunTurn object's
        // largest frame (the runTurn body) + the largest frame across the stage objects
        // (whichever stage that is — the budget doesn't need per-stage precision).
        func maxFrame(inObject name: String) -> Int {
            frames.filter { $0.key.hasPrefix(name + "|") }.map(\.value).max() ?? 0
        }
        let main = maxFrame(inObject: objNames[0])
        let stageMax = objNames.dropFirst().map { maxFrame(inObject: $0) }.max() ?? 0
        var report: [String] = ["runTurn-main: \(main) B", "largest stage frame: \(stageMax) B"]
        XCTAssertGreaterThan(main, 0, "runTurn body frame not found")
        for stage in Self.stageNames {
            XCTAssertTrue(dis.contains(stage),
                "stage function '\(stage)' not found in the objects — the stage split was undone?")
        }
        let peak = main + stageMax
        report.append("PEAK: \(peak) B (budget \(Self.peakBudgetBytes))")
        XCTAssertLessThanOrEqual(peak, Self.peakBudgetBytes,
            "runTurn debug stack peak regressed — split the offending stage, don't ride the budget:\n"
            + report.joined(separator: "\n"))
    }
}

// MARK: - stage-contract naming lint (context-IR step 1)

/// 2026-07-12 operator order ("阶段合同具名化"): runTurn's stage functions must return NAMED
/// context types (BAS*StageContext), not ad-hoc tuples — the tuple contracts were the measured
/// signature of distributed context engineering (9/4/10/16/12 anonymous values). A red here
/// means someone added a stage returning a bare tuple: name its contract instead.
extension BASRunTurnFrameBudgetTests {
    func testStageContractsAreNamedTypesNotTuples() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BASHostKit")
        var src = ""
        for f in ["EBrainRuntimeCoordinator+RunTurn.swift", "EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift",
                  "EBrainRuntimeCoordinator+RunTurnStagesEscalateRender.swift", "EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift"] {
            src += try String(contentsOf: root.appendingPathComponent(f), encoding: .utf8) + "\n"
        }
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

// MARK: - context-compiler authority lint (context-IR step 3)

/// The turn-level context compiler is the SINGLE admission authority: after
/// `BASTurnContextCompiler.compile(...)` in runTurn, no code may consume the raw
/// `routedBudget` directly — scalar admissions go through the plan's per-stage sections
/// (`contextPlan.deliberate.*`, `contextPlan.risk.*`) and whole-frame service passes go
/// through `contextPlan.routedBudget`. A red here means someone bypassed the compiler.
extension BASRunTurnFrameBudgetTests {
    func testContextPlanIsTheOnlyBudgetAuthorityAfterCompile() throws {
        let src = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift"),
            encoding: .utf8)
        let lines = src.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let compileAt = lines.firstIndex(where: { $0.contains("BASTurnContextCompiler.compile(") })
        else {
            XCTFail("runTurn does not compile a BASTurnContextPlan — the context compiler is unwired")
            return
        }
        // bare `routedBudget` use = the token not preceded by `.` (member access off the plan)
        // and not followed by `:` (an argument LABEL is fine — its value must be plan-sourced).
        let bareUse = try NSRegularExpression(pattern: "(?<![.\\w])routedBudget(?!\\s*:)")
        var offenders: [String] = []
        for (i, line) in lines.enumerated() where i > compileAt {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
            let range = NSRange(line.startIndex..., in: line)
            if bareUse.firstMatch(in: line, range: range) != nil {
                offenders.append("line \(i + 1): \(line.trimmingCharacters(in: .whitespaces).prefix(80))")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "raw routedBudget consumed after the context compiler (route it through contextPlan):\n"
            + offenders.joined(separator: "\n"))
    }
}

// MARK: - declared-reads lint (context-IR step 4)

/// Step 4 ("读面声明"): stage implementations are coordinator METHODS with explicit
/// parameters — a method cannot lexically capture runTurn locals, so the parameter list IS
/// the declared read surface (the compiler enforces it; a nested local func can silently
/// capture anything). Mutated context flows back through the named output contexts.
extension BASRunTurnFrameBudgetTests {
    func testStageReadsAreDeclaredParameters() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BASHostKit")
        let runTurn = try String(
            contentsOf: root.appendingPathComponent("EBrainRuntimeCoordinator+RunTurn.swift"),
            encoding: .utf8)
        // (a) no NESTED stage functions (8-space indent = inside runTurn = capture-capable)
        let nested = runTurn.split(separator: "\n").enumerated().filter { _, l in
            l.hasPrefix("        func ") && l.contains("Stage") && !l.contains("markStage")
        }
        XCTAssertTrue(nested.isEmpty,
            "stage functions nested in runTurn can capture reads silently — hoist to methods:\n"
            + nested.map { "line \($0.0 + 1): \($0.1.trimmingCharacters(in: .whitespaces).prefix(80))" }
                .joined(separator: "\n"))
        // (b) each stage exists as a method whose reads are DECLARED (non-empty parameter list)
        var all = runTurn
        for f in ["EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift", "EBrainRuntimeCoordinator+RunTurnStagesEscalateRender.swift",
                  "EBrainRuntimeCoordinator+RunTurnStagesAuditAssemble.swift"] {
            if let s = try? String(contentsOf: root.appendingPathComponent(f), encoding: .utf8) {
                all += s
            }
        }
        for stage in ["memoryDeliberateStage", "riskStageA", "riskStageB",
                      "renderStageA", "renderStageB", "assembleStage"] {
            XCTAssertTrue(all.contains("func \(stage)("),
                "stage method \(stage) not found in the coordinator surface")
            XCTAssertFalse(all.contains("func \(stage)()"),
                "\(stage) declares NO reads (empty parameter list) — the read surface must be explicit")
        }
    }
}
#endif
