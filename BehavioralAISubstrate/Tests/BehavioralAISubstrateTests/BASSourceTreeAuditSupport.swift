import Foundation

/// audit tests-arch ⑤ — shared repo-root resolver for the source-tree-audit test suites.
///
/// ~10 suites hardcoded `BAS_PROJECT_ROOT ?? "/Users/changgeng/Project/Project06/Project06/
/// BehavioralAISubstrate"`, so they read the ORIGINAL dev box's absolute path and break (or silently
/// mis-read) on CI or any other machine. This resolves the root from `#filePath` (walk up to the dir
/// containing `Package.swift`), honoring `BAS_PROJECT_ROOT` when set, with the historical hardcoded
/// path kept only as a last-resort fallback.
enum BASSourceTreeAudit {

    /// The repo root, resolved once from THIS file's location (or `BAS_PROJECT_ROOT`).
    static let repoRoot: String = resolveRepoRoot(
        env: ProcessInfo.processInfo.environment, startFilePath: #filePath)

    /// Pure, injectable resolver (unit-testable independent of the ambient env / this machine):
    ///  1. `BAS_PROJECT_ROOT` if set and non-empty;
    ///  2. else walk UP from `startFilePath` (≤16 levels) to the first dir containing `Package.swift`;
    ///  3. else the historical hardcoded path (last resort — keeps behavior if the walk fails).
    static func resolveRepoRoot(env: [String: String], startFilePath: String) -> String {
        if let e = env["BAS_PROJECT_ROOT"], !e.isEmpty { return e }
        var dir = URL(fileURLWithPath: startFilePath).deletingLastPathComponent()
        for _ in 0..<16 {
            let pkg = dir.appendingPathComponent("Package.swift").path
            if FileManager.default.fileExists(atPath: pkg) { return dir.path }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }   // reached filesystem root
            dir = parent
        }
        return "/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
    }
}
