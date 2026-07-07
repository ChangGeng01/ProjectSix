import Foundation

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
        public init(suiteFilters: [String]) { self.suiteFilters = suiteFilters }
    }

    /// Parse the XCTest aggregate line ("Executed N tests, with M failures") — the SAME
    /// signal the triage discipline trusts (never the bare exit code, ch1042 案底).
    public static func parseAggregate(_ output: String) -> (tests: Int, failures: Int)? {
        var tests = 0, failures = 0, seen = false
        for line in output.split(separator: "\n") {
            guard line.contains("Executed"), line.contains("tests, with") else { continue }
            let parts = line.split(separator: " ")
            for (i, p) in parts.enumerated() {
                if p == "Executed", i + 1 < parts.count, let n = Int(parts[i + 1]) {
                    tests = n
                }
                if p.hasPrefix("failure"), i >= 1, let n = Int(parts[i - 1]) {
                    failures = n; seen = true
                }
            }
        }
        return seen ? (tests, failures) : nil
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
        for filter in manifest.suiteFilters {
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
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
            proc.waitUntilExit()
            let dt = Date().timeIntervalSince(t0)
            let agg = parseAggregate(out)
            let verdict: String
            if let a = agg {
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
            print("📊 station suite=\(filter) \(verdict) t=\(String(format: "%.1f", dt))s")
        }
        try? appendToLedger(records, ledgerURL: ledgerURL)
        return records
    }
    #endif
}
