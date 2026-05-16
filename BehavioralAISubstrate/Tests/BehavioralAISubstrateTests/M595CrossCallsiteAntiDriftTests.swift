import XCTest
@testable import BASHostKit

/// **M595 chapter 一百六十六 + chapter 一百六十七 — cross-callsite
/// anti-drift defensive tests**.
///
/// Chapter 一百六十六 discovered that 5 deep-review iterations
/// missed a cross-site drift bug: chapter 一百五十七 M583 fixed the
/// audit-side `kunlunMatchedForGate` evaluation but left the gate-
/// side at line 1050 with the OLD risk-level lookup. Doc-comment
/// at line 1029-1035 claimed "same output by construction" — false.
///
/// **Lesson** (chapter 一百六十六 §166.9): doc-comment claims of
/// cross-site parity must be verified by code-reading, not trusted.
///
/// **This test file**: source-code-level regression guards. If
/// anyone re-introduces an inline magic literal at a known mirror-
/// pair site (deviationThreshold 0.7, confidenceFloor 1.0), the
/// test fails. Catches drift before it ships.
///
/// **Pattern**: read the source file as text, grep for inline
/// literals that should have been replaced with named constant
/// references, assert 0 matches.
final class M595CrossCallsiteAntiDriftTests: XCTestCase {

    /// Path to the BASHostKit source directory containing the
    /// coordinator family (main file + all `+*.swift` extension
    /// splits per chapter 六百六十一 / M2021 doctrine)。
    private var coordinatorSourceDirectory: String {
        // Resolve via bundle path-up from test bundle
        // (Swift Package Manager test convention).
        let testFile = #filePath
        let testFileURL = URL(fileURLWithPath: testFile)
        // Test file: .../Tests/BehavioralAISubstrateTests/...
        // Coordinator: .../Sources/BASHostKit/...
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot
            .appendingPathComponent("Sources/BASHostKit")
            .path
    }

    /// Read the concatenated text of the coordinator family
    /// (main file `EBrainRuntimeCoordinator.swift` PLUS all
    /// extension splits `EBrainRuntimeCoordinator+*.swift`)。
    ///
    /// Chapter 六百六十一 / M2021 EBrainRuntimeCoordinator
    /// extension split moved the body code from the main file
    /// (now ~196 LOC) into typed feature extensions:
    ///   - EBrainRuntimeCoordinator+RunTurn.swift
    ///   - EBrainRuntimeCoordinator+CoreHelpers.swift
    ///   - EBrainRuntimeCoordinator+AuditProjectionHelpers.swift
    ///   - …plus ~10 more feature-scoped extension files
    ///
    /// The anti-drift grep MUST scan the whole family,not just
    /// the main file,otherwise call-site relocations look like
    /// regressions when they're just architectural moves。
    ///
    /// Skips test if directory resolution fails (e.g. running
    /// tests via a different layout)。
    private func readCoordinatorSource() throws -> String {
        let dir = coordinatorSourceDirectory
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: dir, isDirectory: &isDir)
        guard exists && isDir.boolValue else {
            throw XCTSkip(
                "Coordinator source directory not found" +
                " at \(dir); test layout may differ.")
        }
        let contents = try FileManager.default
            .contentsOfDirectory(atPath: dir)
        // Pick the coordinator family: main + `+*.swift`
        // extension splits。
        let familyFiles = contents.filter { name in
            return (name == "EBrainRuntimeCoordinator.swift")
                || (name.hasPrefix(
                    "EBrainRuntimeCoordinator+")
                    && name.hasSuffix(".swift"))
        }.sorted()
        guard !familyFiles.isEmpty else {
            throw XCTSkip(
                "No EBrainRuntimeCoordinator family files" +
                " found at \(dir); test layout may differ.")
        }
        var aggregated = ""
        for name in familyFiles {
            let path = (dir as NSString)
                .appendingPathComponent(name)
            aggregated += "\n// === \(name) ===\n"
            aggregated += (try? String(
                contentsOfFile: path,
                encoding: .utf8)) ?? ""
        }
        return aggregated
    }

    /// Pin: `deviationThreshold: 0.7` inline literal MUST NOT
    /// appear in EBrainRuntimeCoordinator.swift. Both call sites
    /// (line 1048 + 1820) must reference the named constant.
    /// Regression guard against chapter 一百六十六 cross-site drift.
    func testNoInlineDeviationThresholdLiteral() throws {
        let source = try readCoordinatorSource()
        // Search for the inline pattern
        let inlinePattern = "deviationThreshold: 0.7"
        // Allow `deviationThreshold: Self.kunlunAxisDeviationThreshold`
        // and similar — the named-constant form.
        let lines = source.split(separator: "\n")
        let offendingLines = lines.enumerated().filter { _, line in
            return line.contains(inlinePattern)
        }
        XCTAssertTrue(
            offendingLines.isEmpty,
            """
            Found \(offendingLines.count) inline
            `deviationThreshold: 0.7` literal(s). Use
            `Self.kunlunAxisDeviationThreshold` instead. Lines:
            \(offendingLines.map { "  L\($0.offset + 1): \($0.element)" }.joined(separator: "\n"))
            """)
    }

    /// Pin: `confidenceFloor` default magic `?? 1.0` MUST NOT
    /// appear inline. Both call sites (line ~1028 + line ~1834)
    /// must reference the named constant.
    func testNoInlineConfidenceFloorLiteral() throws {
        let source = try readCoordinatorSource()
        let inlinePattern = ".confidenceFloor ?? 1.0"
        let lines = source.split(separator: "\n")
        let offendingLines = lines.enumerated().filter { _, line in
            return line.contains(inlinePattern)
        }
        XCTAssertTrue(
            offendingLines.isEmpty,
            """
            Found \(offendingLines.count) inline
            `.confidenceFloor ?? 1.0` literal(s). Use
            `Self.defaultConfidenceFloorWhenNoUncertaintyLedger`
            instead. Lines:
            \(offendingLines.map { "  L\($0.offset + 1): \($0.element)" }.joined(separator: "\n"))
            """)
    }

    /// Pin: gate-side and audit-side BOTH must reference the
    /// named constant. Counts ALL occurrences (including the
    /// declaration line). Source must have ≥3 occurrences:
    /// 1 declaration + ≥2 call sites. Regression guard.
    func testNamedConstantUsedAtBothSites() throws {
        let source = try readCoordinatorSource()
        let occurrences = source.components(
            separatedBy: "kunlunAxisDeviationThreshold")
            .count - 1
        XCTAssertGreaterThanOrEqual(
            occurrences, 3,
            """
            Expected ≥3 occurrences of `kunlunAxisDeviationThreshold`
            (1 declaration + 2 call sites: gate ~1048 + audit ~1820).
            Found \(occurrences). May indicate a call site reverted
            to inline `0.7` literal (chapter 一百六十六 drift).
            """)
    }

    /// Pin: confidenceFloor default constant must be used at
    /// both gate (line ~1028) + audit (line ~1834) sites.
    func testConfidenceFloorConstantUsedAtBothSites() throws {
        let source = try readCoordinatorSource()
        let occurrences = source.components(
            separatedBy:
                "defaultConfidenceFloorWhenNoUncertaintyLedger")
            .count - 1
        XCTAssertGreaterThanOrEqual(
            occurrences, 3,
            """
            Expected ≥3 occurrences of
            `defaultConfidenceFloorWhenNoUncertaintyLedger`
            (1 declaration + 2 call sites: gate ~1028 + audit ~1834).
            Found \(occurrences). May indicate a call site reverted
            to inline `?? 1.0` literal (chapter 一百六十六 drift).
            """)
    }

    /// Pin: gate-side AND audit-side MUST share the 3-predicate
    /// evaluation via the typed factory。 Regression guard against
    /// chapter 一百六十六 finding (M583 partial fix at chapter 一百
    /// 五十七 only updated audit-side)。
    ///
    /// Chapter 四百九十四 / M1355 structural strengthening:
    /// BOTH sites now call BASTurnAuditProjectionsKunlunAxisProtocol
    /// .compute(...) — there is no longer a separate
    /// `respectsHostBoundaryForGate` local。 The predicate semantics
    /// live INSIDE the factory,which makes drift structurally
    /// impossible (single source-of-truth)。
    ///
    /// The test now verifies BOTH sites use the shared factory
    /// (≥2 calls to .compute on the audit-protocol bundle)。
    func testGateSideUses3PredicateEvaluation() throws {
        let source = try readCoordinatorSource()
        // Audit-side factory call
        XCTAssertTrue(
            source.contains(
                "BASTurnAuditProjectionsKunlunAxisProtocol"),
            """
            Coordinator missing
            BASTurnAuditProjectionsKunlunAxisProtocol factory
            reference。 Chapter 493 audit-side fold may have
            been reverted (M583 chapter 一百五十七 predicate
            evaluation must run via the shared factory)。
            """)
        // Both sites pass quarantineRecordsIsEmpty (gate=true
        // pre-quarantine, audit=quarantineRecords.isEmpty)
        let factoryCallCount = source.components(
            separatedBy: "BASTurnAuditProjectionsKunlunAxis" +
                "Protocol.compute")
            .count - 1
        XCTAssertGreaterThanOrEqual(
            factoryCallCount, 2,
            """
            Expected ≥2 calls to BASTurnAuditProjectionsKunlun
            AxisProtocol.compute (1 gate-side ~M1355 +
            1 audit-side ~M1349)。 Found \(factoryCallCount)。
            M595 cross-site drift fix relies on SHARED factory
            ownership of the 3-predicate evaluation。
            """)
    }

    // MARK: - M597 chapter 一百六十八 — Meta-tests of anti-drift tests

    /// **M597 chapter 一百六十八 — meta-test**: verify the anti-
    /// drift inline-literal detection mechanism actually catches
    /// what chapter 一百六十六 disclosed. Construct a simulated
    /// source string containing the exact pre-fix inline literal
    /// pattern and assert grep DOES find it.
    ///
    /// Without this meta-test, the anti-drift test could silently
    /// stop working (e.g. if the pattern string changes substrate
    /// formatting) and we'd have no signal until a real drift
    /// occurred and went uncaught.
    func testAntiDriftDetectsKnownPreFixPattern() {
        // Simulated source with chapter 一百六十六 pre-fix inline literal
        let simulatedPreFix = """
        let kunlunAxisForAudit = BASKunlunAxis(
            axisID: "axis-test",
            centerlineRules: ["r1", "r2", "r3"],
            deviationThreshold: 0.7,
            lastAlignmentCheck: "")
        """
        // Run the same grep logic as testNoInlineDeviationThresholdLiteral
        let inlinePattern = "deviationThreshold: 0.7"
        let lines = simulatedPreFix.split(separator: "\n")
        let offendingLines = lines.enumerated().filter { _, line in
            return line.contains(inlinePattern)
        }
        XCTAssertEqual(
            offendingLines.count, 1,
            """
            Anti-drift detection mechanism failed: simulated
            pre-fix source containing `deviationThreshold: 0.7`
            should match exactly 1 line. Found \(offendingLines.count).
            If this fails, the actual chapter 一百六十六 regression
            guard test is non-functional.
            """)
    }

    /// Verify confidenceFloor inline-literal detection works on
    /// known pre-fix pattern.
    func testAntiDriftDetectsKnownPreFixConfidenceFloor() {
        let simulatedPreFix = """
        let unknownReserveForAudit = BASUnknownReserve.derive(
            reserveID: "test",
            confidenceFloor: thoughtFrame.uncertaintyLedger?
                .confidenceFloor ?? 1.0)
        """
        let inlinePattern = ".confidenceFloor ?? 1.0"
        let lines = simulatedPreFix.split(separator: "\n")
        let offendingLines = lines.enumerated().filter { _, line in
            return line.contains(inlinePattern)
        }
        XCTAssertEqual(
            offendingLines.count, 1,
            """
            Anti-drift detection mechanism failed for confidenceFloor.
            """)
    }

    /// Negative test: verify named-constant references DON'T
    /// trigger inline-literal detection (no false positives).
    func testAntiDriftSkipsNamedConstantReferences() {
        let simulatedPostFix = """
        let kunlunAxisForGate = BASKunlunAxis(
            deviationThreshold: Self
                .kunlunAxisDeviationThreshold,
            lastAlignmentCheck: "")
        """
        let inlinePattern = "deviationThreshold: 0.7"
        let lines = simulatedPostFix.split(separator: "\n")
        let offendingLines = lines.enumerated().filter { _, line in
            return line.contains(inlinePattern)
        }
        XCTAssertEqual(
            offendingLines.count, 0,
            """
            Anti-drift detection mechanism produced FALSE POSITIVE:
            `Self.kunlunAxisDeviationThreshold` should NOT match
            `deviationThreshold: 0.7` pattern.
            """)
    }
}
