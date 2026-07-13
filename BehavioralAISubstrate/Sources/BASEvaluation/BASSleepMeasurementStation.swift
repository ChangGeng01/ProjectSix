import Foundation
import BASRuntimeCore

/// deep-audit P2-24 (2026-07-13): a lock-guarded byte box. The sleep station reads a child
/// process's stdout on a background queue and consumes it on the main thread after a
/// possibly-timed-out wait; this box makes that synchronization visible to the compiler
/// (replacing a captured `var` + external NSLock the compiler flagged as a concurrent mutation).
private final class OutBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
    func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}

// P3 睡眠窗测量站(RSI 章程 2026-07-07)——dream-loop 的既有形状,严格 verdict-only。
// 宪法界:站只【测量并记账】,产物是判决候选账本行;不采纳、不改任何开关/常数(采纳权
// 见 P2 candidate:人签)。提案功能不存在(先决门=章程暗点3 的 4B 利用力实验)。
// 三重门(镜像 BASSleepConsolidationDriver 纪律):①静态 opt-in(默认关,ADR-014,
// 关=零成本零构造);②宿主窗许可(充电/空闲/热 nominal——宿主判定,站不猜);
// ③manifest 非空。执行器 macOS-only(Mac = RSI 评估站,审计既定架构事实);
// 设备侧只允许确定性 probe 子集(由宿主 manifest 自律,站在 iOS 上不执行)。

/// One measurement-station run record — the append-only ledger row (JSONL).
public struct BASStationRunRecord: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let startedAtMs: Int64
    public let suiteFilter: String
    public let exitCode: Int32
    public let executedTests: Int
    public let failures: Int
    public let durationS: Double
    /// 判决【候选】行——晨读用;真判决走 triage 纪律(隔离复跑),站不越权。
    public let verdictCandidate: String

    public init(startedAtMs: Int64, suiteFilter: String, exitCode: Int32,
                executedTests: Int, failures: Int, durationS: Double,
                verdictCandidate: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.startedAtMs = startedAtMs
        self.suiteFilter = suiteFilter
        self.exitCode = exitCode
        self.executedTests = executedTests
        self.failures = failures
        self.durationS = durationS
        self.verdictCandidate = verdictCandidate
    }
}

public enum BASSleepMeasurementStation {

    /// Gate ① — static opt-in (default OFF; off ⇒ callers construct nothing, run nothing).
    public static var stationEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_MEASUREMENT_STATION"] == "1"
    }

    /// What to measure — suite filters run sequentially (one heavy job at a time, 铁律).
    public struct Manifest: Codable, Sendable, Equatable {
        public let suiteFilters: [String]
        /// Per-suite wall-clock ceiling (seconds; default 30min)。夜窗铁律:一个挂死的套件
        /// 不得拖垮整机——超时 = SIGKILL 整个进程组(swift driver + 真正挂死满载的孙 xctest
        /// 二进制)+ TIMEOUT 判决候选行,然后【停整站】(audit H20:绝不在一个挂死套件之上再
        /// 起第二个重活——该机曾因这种 pile-on 冻结、被迫重启)。剩余套件记 SKIPPED 行。
        public let perSuiteTimeoutS: Double
        public init(suiteFilters: [String], perSuiteTimeoutS: Double = 1_800) {
            self.suiteFilters = suiteFilters
            self.perSuiteTimeoutS = max(30, perSuiteTimeoutS)
        }
    }

    /// Parse the XCTest aggregate ("Executed N test(s), with M failure(s)") — the SAME
    /// signal the triage discipline trusts (never the bare exit code, ch1042 案底).
    /// 复审修6:多 test-bundle 下【求和 bundle 级聚合】(跟在 'All tests'/'Selected tests'
    /// 套件行之后的那条)而非取末行——两 bundle 时末行覆写曾把红 bundle 洗成 "GREEN 0";
    /// 无 bundle 级行时回退为全行求和(过计但失败检测方向安全)。单数 "1 test" 兼容。
    public static func parseAggregate(_ output: String) -> (tests: Int, failures: Int)? {
        func parseLine(_ line: Substring) -> (Int, Int)? {
            guard line.contains("Executed"), line.contains(", with") else { return nil }
            var t: Int?, f: Int?
            let parts = line.split(separator: " ")
            for (i, p) in parts.enumerated() {
                if p == "Executed", i + 1 < parts.count { t = Int(parts[i + 1]) }
                if p.hasPrefix("failure"), i >= 1 { f = Int(parts[i - 1]) }
            }
            if let t, let f { return (t, f) }
            return nil
        }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        var bundleT = 0, bundleF = 0, bundleSeen = false
        var allT = 0, allF = 0, allSeen = false
        var prevWasTopSuite = false
        for line in lines {
            if let (t, f) = parseLine(line) {
                if prevWasTopSuite { bundleT += t; bundleF += f; bundleSeen = true }
                allT += t; allF += f; allSeen = true
            }
            prevWasTopSuite = line.contains("Test Suite 'All tests'")
                || line.contains("Test Suite 'Selected tests'")
        }
        if bundleSeen { return (bundleT, bundleF) }
        return allSeen ? (allT, allF) : nil
    }

    /// 复审修5b:swift-testing(@Test)失败不产生 XCTest 聚合行——单独检测 ✘ 标记。
    public static func swiftTestingFailures(_ output: String) -> Int {
        output.split(separator: "\n").filter {
            $0.contains("✘") && ($0.contains("recorded an issue") || $0.contains("failed"))
        }.count
    }

    /// Append records to the JSONL ledger (append-only by construction — O_APPEND semantics;
    /// never rewrites, never deletes).
    public static func appendToLedger(_ records: [BASStationRunRecord], ledgerURL: URL) throws {
        let dir = ledgerURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: ledgerURL.path) {
            FileManager.default.createFile(atPath: ledgerURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: ledgerURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        let encoder = JSONEncoder()
        for r in records {
            var line = try encoder.encode(r)
            line.append(Data("\n".utf8))
            try handle.write(contentsOf: line)
        }
    }

    /// Read the ledger back (round-trip acceptance: 晨读 = 解析器往返). Unparseable lines
    /// are surfaced by count, never silently dropped.
    public static func readLedger(ledgerURL: URL) -> (records: [BASStationRunRecord], unparseable: Int) {
        guard let data = try? Data(contentsOf: ledgerURL),
              let text = String(data: data, encoding: .utf8) else { return ([], 0) }
        var records: [BASStationRunRecord] = []
        var bad = 0
        let decoder = JSONDecoder()
        for line in text.split(separator: "\n") where !line.isEmpty {
            if let r = try? decoder.decode(BASStationRunRecord.self, from: Data(line.utf8)) {
                records.append(r)
            } else {
                bad += 1
            }
        }
        return (records, bad)
    }

    #if os(macOS)
    /// audit H20 — where a per-suite timeout sends SIGKILL. Killing the whole process GROUP
    /// reaps the grandchild xctest binary (the process that actually hangs at full load), not
    /// just the swift driver. `.single` is the self-protecting fallback.
    public enum StationKillTarget: Equatable {
        case group(pid_t)    // kill(-pid, SIGKILL) — child is its own group leader
        case single(pid_t)   // kill(pid,  SIGKILL) — child shares our group; group-kill unsafe
    }

    /// Decide the SIGKILL target. Kill the whole group ONLY when the child is its own group
    /// leader (`childPgid == pid`) AND that group differs from the station's own group — so the
    /// station can never SIGKILL itself. Otherwise fall back to the single child pid.
    public static func killTargetForTimeout(
        pid: pid_t, childPgid: pid_t, ownPgid: pid_t
    ) -> StationKillTarget {
        if childPgid == pid && childPgid != ownPgid { return .group(pid) }
        return .single(pid)
    }

    /// audit H20 — the remaining suites to SKIP when the station halts after a timeout (the
    /// one-heavy-task iron law: never launch another heavy suite while a hung one may survive).
    public static func suitesToSkipAfterHalt(
        all: [String], haltedIndex: Int
    ) -> [String] {
        guard haltedIndex >= 0, haltedIndex + 1 < all.count else { return [] }
        return Array(all[(haltedIndex + 1)...])
    }

    /// Gate ②③ + execute (macOS station only). `windowPermitted` is the HOST's verdict
    /// (charging/idle/thermal-nominal) — the station never guesses device state itself.
    /// Returns nil when a gate says no (byte-equal off path).
    @discardableResult
    public static func runIfPermitted(
        manifest: Manifest, windowPermitted: Bool, ledgerURL: URL,
        packageDirectory: URL, nowMs: Int64
    ) -> [BASStationRunRecord]? {
        guard stationEnabled else { return nil }                    // 门①
        guard windowPermitted else { return nil }                   // 门②
        guard !manifest.suiteFilters.isEmpty else { return nil }    // 门③
        var records: [BASStationRunRecord] = []
        let ownPgid = getpgrp()   // audit H20: the station's own process group — never SIGKILL it
        for (suiteIndex, filter) in manifest.suiteFilters.enumerated() {
            let t0 = Date()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            proc.arguments = ["test", "--filter", filter]
            proc.currentDirectoryURL = packageDirectory
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
            } catch {
                records.append(BASStationRunRecord(
                    startedAtMs: nowMs, suiteFilter: filter, exitCode: -1,
                    executedTests: 0, failures: 0, durationS: 0,
                    verdictCandidate: "LAUNCH-FAIL: \(error)"))
                continue
            }
            // audit H20: put the child in its OWN process group so a timeout can SIGKILL the whole
            // group (swift driver + the grandchild xctest binary that actually hangs), not only the
            // driver. Best-effort — races the child's exec; the GUARANTEED invariant-preserver is
            // the station halt below (killTargetForTimeout self-protects if the child didn't detach).
            setpgid(proc.processIdentifier, proc.processIdentifier)
            // 超时看门狗:后台读避免管道阻塞;截止即 terminate(升级 group-kill)。
            // audit organ-eval MED-1: the child's stdout is WRITTEN by the read thread and READ
            // by this thread after a wait that CAN TIME OUT — so on the timeout path the read
            // raced an in-flight write (torn read / UB). deep-audit P2-24 (2026-07-13): a
            // lock-guarded box makes that synchronization VISIBLE to the compiler (was a captured
            // `var outData` + external NSLock, which reads as a concurrent mutation of a captured
            // var — a warning today, a Swift-6-language-mode error tomorrow).
            let outBox = OutBox()
            let readQueue = DispatchQueue(label: "bas.station.read")
            let readDone = DispatchSemaphore(value: 0)
            readQueue.async {
                let d = pipe.fileHandleForReading.readDataToEndOfFile()
                outBox.set(d)
                readDone.signal()
            }
            let deadline = Date().addingTimeInterval(manifest.perSuiteTimeoutS)
            var timedOut = false
            while proc.isRunning {
                if Date() > deadline {
                    timedOut = true
                    // audit H20: SIGTERM the driver, then SIGKILL the whole process GROUP so the
                    // hung grandchild xctest binary dies too (was: kill only the direct child →
                    // the grandchild survived at full load and the station piled on the next suite).
                    proc.terminate()
                    Thread.sleep(forTimeInterval: 5)
                    if proc.isRunning {
                        let pid = proc.processIdentifier
                        switch Self.killTargetForTimeout(
                            pid: pid, childPgid: getpgid(pid), ownPgid: ownPgid) {
                        case .group(let p):  kill(-p, SIGKILL)
                        case .single(let p): kill(p, SIGKILL)
                        }
                    }
                    // Close the pipe's write end so the background reader can't block forever on a
                    // descendant that still holds it open (was: leaked reader thread).
                    try? pipe.fileHandleForWriting.close()
                    break
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
            proc.waitUntilExit()
            _ = readDone.wait(timeout: .now() + 10)
            let out = String(data: outBox.get(), encoding: .utf8) ?? ""   // organ-eval MED-1: read under lock
            let dt = Date().timeIntervalSince(t0)
            let agg = parseAggregate(out)
            let verdict: String
            let stFails = swiftTestingFailures(out)
            if timedOut {
                verdict = "TIMEOUT after \(Int(manifest.perSuiteTimeoutS))s — killed (process group); " +
                          "STATION HALTED (one-heavy-task invariant); triage by hand"
            } else if stFails > 0 {
                verdict = "RED(swift-testing) \(stFails) ✘ — hand triage (no XCTest aggregate covers these)"
            } else if let a = agg {
                verdict = a.failures == 0
                    ? "GREEN \(a.tests) tests"
                    : "RED \(a.failures)/\(a.tests) — triage required (isolation re-run, flake registry)"
            } else {
                verdict = "NO-AGGREGATE — inspect raw log (never trust exit code alone)"
            }
            records.append(BASStationRunRecord(
                startedAtMs: nowMs, suiteFilter: filter, exitCode: proc.terminationStatus,
                executedTests: agg?.tests ?? 0, failures: agg?.failures ?? 0,
                durationS: dt, verdictCandidate: verdict))
            BASDiagnosticLog.emit("📊 station suite=\(filter) \(verdict) t=\(String(format: "%.1f", dt))s")
            if timedOut {
                // audit H20: HALT the whole station — do NOT launch another heavy suite while a
                // hung process may have survived the kill. The freeze this machine hit was the
                // pile-on of a second suite on top of a hung one. Record the rest as SKIPPED so
                // the ledger shows they were intentionally not run (not silently dropped).
                for skipped in Self.suitesToSkipAfterHalt(
                    all: manifest.suiteFilters, haltedIndex: suiteIndex) {
                    records.append(BASStationRunRecord(
                        startedAtMs: nowMs, suiteFilter: skipped, exitCode: -1,
                        executedTests: 0, failures: 0, durationS: 0,
                        verdictCandidate:
                            "SKIPPED — station halted after prior timeout (one-heavy-task invariant)"))
                    BASDiagnosticLog.emit("⏹️ station suite=\(skipped) SKIPPED — station halted after timeout")
                }
                break
            }
        }
        // audit organ-eval LOW-3: don't silently swallow a ledger-write failure — a lost measurement
        // ledger reads as "no run happened". Non-fatal (records are still returned) but surfaced.
        do {
            try appendToLedger(records, ledgerURL: ledgerURL)
        } catch {
            BASDiagnosticLog.emit("⚠️ station: failed to append \(records.count) record(s) to ledger " +
                  "\(ledgerURL.lastPathComponent): \(error)")
        }
        return records
    }
    #endif
}
