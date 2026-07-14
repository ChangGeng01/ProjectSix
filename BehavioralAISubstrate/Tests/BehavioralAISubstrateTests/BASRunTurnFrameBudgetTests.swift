#if os(macOS)
import XCTest

/// Frame-budget + context-IR lints for runTurn (the cooperative-pool SIGBUS class).
///
/// History: runTurn was a single 129,792-byte -Onone frame; the arc (CoW box → stage split →
/// declared reads) brought the real peak to ~36KB. HARDENED 2026-07-12 after the adversarial
/// teeth audit found evasions in the first-cut lints (fossil objects, single-frame model,
/// multi-line signature blindness, indent-exact nesting checks). Pure classifiers are exposed
/// as statics with negative-control fixtures, per the repo lint pattern.
final class BASRunTurnFrameBudgetTests: XCTestCase {

    /// CONSERVATIVE peak budget. Model (see below): runTurn-main's largest frame + the worst
    /// stage object's TOP-TWO frame sum (a 1-level stage→helper chain bound that also
    /// over-counts sibling co-location — deliberately pessimistic; measured conservative peak
    /// 48,240B at pin time vs ~36KB actual). A red means split the offending stage/helper,
    /// don't ride the budget.
    private static let peakBudgetBytes = 64_000
    static let stageNames = ["memoryDeliberateStage", "riskStageA", "riskStageB",
                             "renderStageA", "renderStageB", "assembleStage"]
    static let runTurnObjectPrefix = "EBrainRuntimeCoordinator+RunTurn"

    private static func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - frame budget

    func testRunTurnDebugPeakFrameStaysUnderBudget() throws {
        let root = Self.packageRoot()
        let objDir = root.appendingPathComponent(".build/arm64-apple-macosx/debug/BASHostKit.build")
        guard FileManager.default.fileExists(atPath: objDir.path) else {
            // HONEST STATUS (skip triage, 2026-07-14): under Apple Swift 6.4 the default build
            // system is swiftbuild, which never produces this native-SPM object dir, and NO repo
            // script passes --build-system native (scripts/swift-test-headless.sh runs plain
            // `swift test`). So on a default checkout this guard ALWAYS fires and the only test
            // here that measures actual bytes never runs. It is arm-able, not dead — VERIFIED
            // 2026-07-14, this exact sequence produces the obj dir and the lint then runs and
            // PASSES (6 tests, 0 skipped, 0 failures; runTurn peak is genuinely under budget):
            //
            //     swift build --build-system native --build-tests
            //     swift test --build-system native --filter BASRunTurnFrameBudgetTests
            //
            // ★ SHELF LIFE: that build emits "'--build-system native' has been deprecated and
            //   will be removed in a future release". When it goes, this lint dies for real —
            //   the durable fix is to teach objDir the swiftbuild layout, NOT to keep leaning on
            //   a deprecated flag. Treat that removal as the trigger to do the port.
            //
            // Until armed, the frame budget is NOT mechanically enforced by CI. Do not describe
            // it as "pinned" elsewhere without saying by what — the 5 sibling files that made
            // that claim (in 3 mutually contradictory figures) were corrected in the same commit
            // as this comment. The 5 grep-based source lints in this file DO run every pass and
            // are what actually holds the line today.
            throw XCTSkip(
                "native-SPM object dir absent — the default swiftbuild layout does not produce "
                + "\(objDir.lastPathComponent), so the BYTE-MEASURING frame-budget lint cannot "
                + "run here. Arm it with: swift test --build-system native --filter "
                + "BASRunTurnFrameBudgetTests. The source-shape lints in this file still ran.")
        }
        // DISCOVER runTurn-family objects by prefix — a renamed or added stage file is included
        // automatically instead of greening the lint forever (audit: rename-evasion).
        let objNames = try FileManager.default.contentsOfDirectory(atPath: objDir.path)
            .filter { $0.hasPrefix(Self.runTurnObjectPrefix) && $0.hasSuffix(".swift.o") }
            .sorted()
        XCTAssertGreaterThanOrEqual(objNames.count, 4,
            "expected the runTurn + ≥3 stage objects under \(objDir.path); found \(objNames) — "
            + "if stage files were renamed out of the family prefix, update runTurnObjectPrefix")

        // FOSSIL GUARD (audit: beta/swiftbuild runs measured stale stable-toolchain objects
        // and passed on old code). Layout detection via OUR OWN bundle path: if this test
        // process was built into the native-SPM layout, the objects come from THIS build and
        // are fresh by construction; if we are running from the swiftbuild layout
        // (.build/out/Products), the native objects belong to some OLDER stable-toolchain
        // build — skip LOUDLY instead of certifying fossils. (mtime comparison is NOT usable:
        // SPM skips recompiles by content hash, so a touched-but-unchanged source trips it.)
        let ourBundle = Bundle(for: Self.self).bundlePath
        guard ourBundle.contains("arm64-apple-macosx") else {
            throw XCTSkip("running from a non-native build layout (\(ourBundle)) — the native "
                + "objects may be fossils; the frame budget bites on stable-toolchain runs "
                + "(swift-test-headless.sh)")
        }

        var dis = ""
        for name in objNames {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            p.arguments = ["llvm-objdump", "-d", objDir.appendingPathComponent(name).path]
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw XCTSkip("llvm-objdump unavailable") }
            // prefix each symbol header with its object so per-object attribution survives
            // (each object's FIRST function hides under the local label ltmp0 — name-matching
            // hits thunks: measured 304B thunk vs 28,432B real body).
            for line in String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false) {
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

        func topFrames(inObject name: String, _ n: Int) -> [Int] {
            frames.filter { $0.key.hasPrefix(name + "|") }.map(\.value)
                .sorted(by: >).prefix(n).map { $0 }
        }
        // main object = the one holding runTurn itself (exact file name, not a stage file)
        let mainObj = objNames.first { $0 == "\(Self.runTurnObjectPrefix).swift.o" }
        let main = mainObj.map { topFrames(inObject: $0, 1).first ?? 0 } ?? 0
        XCTAssertGreaterThan(main, 0, "runTurn body frame not found in \(mainObj ?? "?")")
        // worst stage object: top-2 sum = 1-level stage→helper chain bound (audit: the old
        // single-frame model missed helper chains entirely).
        let stageBound = objNames.filter { $0 != mainObj }
            .map { topFrames(inObject: $0, 2).reduce(0, +) }.max() ?? 0
        for stage in Self.stageNames {
            XCTAssertTrue(dis.contains(stage),
                "stage function '\(stage)' not found in the objects — the stage split was undone?")
        }
        let peak = main + stageBound
        XCTAssertLessThanOrEqual(peak, Self.peakBudgetBytes,
            "runTurn debug stack conservative peak regressed — split the offending stage/helper, "
            + "don't ride the budget:\nrunTurn-main: \(main) B\nworst stage object top-2 bound: "
            + "\(stageBound) B\nPEAK: \(peak) B (budget \(Self.peakBudgetBytes))")
    }

    // MARK: - stage-contract naming lint (context-IR step 1)

    /// Pure classifier: signatures of `func *Stage*` whose return type is a bare tuple.
    /// Scans SIGNATURE SPANS (match → first `{`), so multi-line house formatting is covered
    /// (audit: the first cut only matched single-line `func … -> (`).
    static func tupleReturningStageSignatures(in src: String) -> [String] {
        var offenders: [String] = []
        let funcRe = try! NSRegularExpression(pattern: "func\\s+\\w*[Ss]tage\\w*\\s*\\(")
        let ns = src as NSString
        for m in funcRe.matches(in: src, range: NSRange(location: 0, length: ns.length)) {
            let start = m.range.location
            guard let braceRange = ns.range(of: "{", options: [], range: NSRange(location: start, length: min(4_000, ns.length - start))).toOptional() else { continue }
            let sig = ns.substring(with: NSRange(location: start, length: braceRange.location - start))
            if sig.contains("markStage") { continue }
            // tuple return: the text after the LAST `->` in the signature starts with `(`
            if let arrow = sig.range(of: "->", options: .backwards) {
                let ret = sig[arrow.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if ret.hasPrefix("(") {
                    offenders.append(sig.replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return offenders
    }

    func testStageContractsAreNamedTypesNotTuples() throws {
        let src = try Self.combinedStageSurface()
        let offenders = Self.tupleReturningStageSignatures(in: src)
        XCTAssertTrue(offenders.isEmpty,
            "stage functions returning anonymous tuples (name the contract as a BAS*StageContext):\n"
            + offenders.map { String($0.prefix(120)) }.joined(separator: "\n"))
        for ty in ["BASMemoryDeliberateStageContext", "BASRiskBindStageContext",
                   "BASRiskEscalateStageContext", "BASRenderVerdictStageContext",
                   "BASAuditProjectionStageContext"] {
            XCTAssertTrue(src.contains(ty), "stage contract type \(ty) not wired into runTurn")
        }
    }

    func testTupleSignatureClassifierFixtures() {
        typealias L = BASRunTurnFrameBudgetTests
        // the exact house-style evasion the audit demonstrated: multi-line signature
        XCTAssertEqual(L.tupleReturningStageSignatures(in: """
            func riskStageX(
                request: BASEBrainTurnRequest,
                contextPlan: BASTurnContextPlan
            ) -> (BASActionPermit, BASRiskCard) {
            """).count, 1, "multi-line tuple signature must be caught")
        // named-type return passes
        XCTAssertTrue(L.tupleReturningStageSignatures(in:
            "func riskStageX(\n  a: Int\n) -> BASRiskBindStageContext {").isEmpty)
        // markStage exempt; non-stage funcs exempt
        XCTAssertTrue(L.tupleReturningStageSignatures(in:
            "func markStage(_ label: String) -> (Int, Int) {").isEmpty)
        XCTAssertTrue(L.tupleReturningStageSignatures(in:
            "func helper() -> (Int, Int) {").isEmpty)
    }

    // MARK: - context-compiler authority lint (context-IR step 3)

    func testContextPlanIsTheOnlyBudgetAuthorityAfterCompile() throws {
        let src = try String(
            contentsOf: Self.packageRoot()
                .appendingPathComponent("Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift"),
            encoding: .utf8)
        let lines = src.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let compileAt = lines.firstIndex(where: { $0.contains("BASTurnContextCompiler.compile(") })
        else {
            XCTFail("runTurn does not compile a BASTurnContextPlan — the context compiler is unwired")
            return
        }
        // bare `routedBudget` use = the token not preceded by `.` (member access off the plan)
        // and not followed by `:` (an argument LABEL is fine — its value must be plan-sourced;
        // an ALIAS `let rb = routedBudget` is itself a flagged bare use).
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

    // MARK: - declared-reads lint (context-IR step 4)

    /// Pure classifier: capture-capable stage definitions inside runTurn's file — nested
    /// `func *Stage*` at ANY indent deeper than extension-method level, or a stage-named
    /// CLOSURE binding (audit: the first cut matched exactly-8-space indent only and closures
    /// not at all).
    static func captureCapableStageDefinitions(in src: String) -> [String] {
        var offenders: [String] = []
        let nestedFunc = try! NSRegularExpression(pattern: "^\\s{5,}func\\s+\\w*[Ss]tage\\w*\\s*\\(")
        let closureBind = try! NSRegularExpression(
            pattern: "(let|var)\\s+\\w*[Ss]tage\\w*\\s*(:[^=\\n]*)?=\\s*\\{")
        for (i, lineSub) in src.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = String(lineSub)
            if line.contains("markStage(_") || line.contains("func markStage(") { continue }
            let range = NSRange(line.startIndex..., in: line)
            if nestedFunc.firstMatch(in: line, range: range) != nil
                || closureBind.firstMatch(in: line, range: range) != nil {
                offenders.append("line \(i + 1): \(line.trimmingCharacters(in: .whitespaces).prefix(90))")
            }
        }
        return offenders
    }

    func testStageReadsAreDeclaredParameters() throws {
        let runTurn = try String(
            contentsOf: Self.packageRoot()
                .appendingPathComponent("Sources/BASHostKit/EBrainRuntimeCoordinator+RunTurn.swift"),
            encoding: .utf8)
        let offenders = Self.captureCapableStageDefinitions(in: runTurn)
        XCTAssertTrue(offenders.isEmpty,
            "capture-capable stage definitions inside runTurn (hoist to methods with parameters):\n"
            + offenders.joined(separator: "\n"))
        let all = try Self.combinedStageSurface()
        for stage in Self.stageNames {
            XCTAssertTrue(all.contains("func \(stage)("),
                "stage method \(stage) not found in the coordinator surface")
            XCTAssertFalse(all.contains("func \(stage)()"),
                "\(stage) declares NO reads (empty parameter list) — the read surface must be explicit")
        }
    }

    func testCaptureClassifierFixtures() {
        typealias L = BASRunTurnFrameBudgetTests
        // deeper-nested func (12 spaces — the audit's indent evasion)
        XCTAssertEqual(L.captureCapableStageDefinitions(in:
            "            func sneakyStage() -> Int {").count, 1)
        // stage-named closure binding
        XCTAssertEqual(L.captureCapableStageDefinitions(in:
            "        let shadowStage = { () -> Int in 1 }()").count, 1)
        // extension-level method (4 spaces) passes; markStage passes
        XCTAssertTrue(L.captureCapableStageDefinitions(in:
            "    func riskStageA(\n        request: R\n    ) -> C {").isEmpty)
        XCTAssertTrue(L.captureCapableStageDefinitions(in:
            "        func markStage(_ label: String) {").isEmpty)
    }

    // MARK: - shared

    static func combinedStageSurface() throws -> String {
        let dir = packageRoot().appendingPathComponent("Sources/BASHostKit")
        // prefix-based discovery: renamed/added stage files stay covered
        var src = ""
        for f in try FileManager.default.contentsOfDirectory(atPath: dir.path)
        where f.hasPrefix(runTurnObjectPrefix) && f.hasSuffix(".swift") {
            src += try String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8) + "\n"
        }
        return src
    }
}

private extension NSRange {
    func toOptional() -> NSRange? { location == NSNotFound ? nil : self }
}
#endif
