import XCTest
@testable import BASOrchestration
@testable import BASMemory

/// M459-M463 (chapter 一百二十一) — strict 14-layer Cthulhu
/// whitepaper audit closures.
final class M459StrictCthulhuAuditTests: XCTestCase {

    // MARK: - M459 BASAbyssalOrganAlias

    func testOrganAliasCardinalityIsSix() {
        XCTAssertEqual(BASAbyssalOrganAlias.allCases.count, 6,
                       "Abyssal VINF §4.2 lists 6 organ names")
    }

    func testOrganAliasRawValuesAreStable() {
        // Pin stable kebab-case raw values — cross-module
        // string consumers key on these.
        XCTAssertEqual(
            BASAbyssalOrganAlias.mainCoreCortex.rawValue,
            "main-core-cortex")
        XCTAssertEqual(
            BASAbyssalOrganAlias.counterfactualForge.rawValue,
            "counterfactual-forge")
        XCTAssertEqual(
            BASAbyssalOrganAlias.critiqueBladeCore.rawValue,
            "critique-blade-core")
        XCTAssertEqual(
            BASAbyssalOrganAlias.riskRidge.rawValue,
            "risk-ridge")
        XCTAssertEqual(
            BASAbyssalOrganAlias.oldSealCore.rawValue,
            "old-seal-core")
        XCTAssertEqual(
            BASAbyssalOrganAlias.minimalResonanceCore.rawValue,
            "minimal-resonance-core")
    }

    func testEveryOrganAliasHasWhitePaperRef() {
        for alias in BASAbyssalOrganAlias.allCases {
            XCTAssertFalse(alias.whitePaperRef.isEmpty,
                           "every alias must cite whitepaper")
            XCTAssertTrue(alias.whitePaperRef.contains("§"),
                          "whitePaperRef must contain section anchor")
        }
    }

    /// **Cthulhu RL10 doctrine pin** — public surface names are
    /// formal, never 恐怖化. Pin all 6 mappings.
    func testEveryOrganAliasHasFormalPublicName() {
        let pairs: [(BASAbyssalOrganAlias, String)] = [
            (.mainCoreCortex, "Scout"),
            (.counterfactualForge, "Planner"),
            (.critiqueBladeCore, "Critic"),
            (.riskRidge, "Risk"),
            (.oldSealCore, "Sovereign"),
            (.minimalResonanceCore, "MinimalSurface"),
        ]
        for (alias, expected) in pairs {
            XCTAssertEqual(alias.publicSurfaceName, expected)
            // Doctrine pin — public name never contains
            // forbidden Cthulhu vocabulary.
            let forbidden = ["abyss", "abyssal", "cthulhu",
                             "forbidden", "deep", "dark"]
            for token in forbidden {
                XCTAssertFalse(
                    alias.publicSurfaceName.lowercased()
                        .contains(token),
                    "public name '\(alias.publicSurfaceName)' " +
                    "must not contain forbidden token '\(token)' " +
                    "(RL10 主品牌不默认恐怖化)")
            }
        }
    }

    // MARK: - M460 BASHumanAnchorProfile

    func testHumanAnchorProfileSchemaVersion() {
        XCTAssertEqual(
            BASHumanAnchorProfile.currentSchemaVersion, "1.0.0")
    }

    func testHumanAnchorProfileTrimsAndFiltersEmpties() {
        let profile = BASHumanAnchorProfile(
            profileID: "  prof-1  ",
            hostRef: "host-x",
            dignityInvariants: ["no-shame", "  ", "no-condescension"],
            noExploitationGuards: [""],
            sensitivityWindows: ["grief-30d"],
            anchoringRituals: ["morning-3-breath", "  "])
        XCTAssertEqual(profile.profileID, "prof-1")
        XCTAssertEqual(profile.dignityInvariants,
                       ["no-shame", "no-condescension"])
        XCTAssertEqual(profile.noExploitationGuards, [])
        XCTAssertEqual(profile.sensitivityWindows, ["grief-30d"])
        XCTAssertEqual(profile.anchoringRituals,
                       ["morning-3-breath"])
    }

    func testHumanAnchorProfileRoundTripCodable() throws {
        let profile = BASHumanAnchorProfile(
            profileID: "p",
            hostRef: "h",
            dignityInvariants: ["a"],
            noExploitationGuards: ["b"],
            sensitivityWindows: ["c"],
            anchoringRituals: ["d"])
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder()
            .decode(BASHumanAnchorProfile.self, from: data)
        XCTAssertEqual(profile, decoded)
    }

    // MARK: - M461 BASNarrativeDistortionMap

    func testNarrativeDistortionMapSchemaVersion() {
        XCTAssertEqual(
            BASNarrativeDistortionMap.currentSchemaVersion, "1.0.0")
    }

    func testNarrativeDistortionMapParallelArrayInvariant() {
        // subjectRefs must match distortionsBySubject keys; init
        // filters to valid keys only.
        let dist = BASNarrativeDistortion(
            distortionID: "d-1",
            realityDenial: 0.5,
            historyRewrite: 0,
            forcedClosure: 0,
            roleInversion: 0,
            urgencyMask: 0,
            confidence: 0.5)
        let map = BASNarrativeDistortionMap(
            mapID: "m-1",
            subjectRefs: ["sub-1", "sub-orphan"],
            distortionsBySubject: ["sub-1": dist])
        XCTAssertEqual(map.subjectRefs, ["sub-1"],
                       "orphan refs without distortions filtered")
        XCTAssertEqual(map.distortionsBySubject.count, 1)
    }

    func testNarrativeDistortionMapAggregateMaxComputes() {
        let lo = BASNarrativeDistortion(
            distortionID: "lo",
            realityDenial: 0.2,
            historyRewrite: 0.1,
            forcedClosure: 0.1,
            roleInversion: 0.1,
            urgencyMask: 0.1,
            confidence: 0.5)
        let hi = BASNarrativeDistortion(
            distortionID: "hi",
            realityDenial: 0.85,
            historyRewrite: 0.1,
            forcedClosure: 0.1,
            roleInversion: 0.1,
            urgencyMask: 0.1,
            confidence: 0.5)
        let map = BASNarrativeDistortionMap(
            mapID: "m-2",
            subjectRefs: ["lo-sub", "hi-sub"],
            distortionsBySubject: [
                "lo-sub": lo, "hi-sub": hi,
            ])
        XCTAssertEqual(map.aggregateMaxDistortion, 0.85,
                       accuracy: 0.001,
                       "aggregate-max picks the dominant axis " +
                       "across subjects")
    }

    func testNarrativeDistortionMapEmptyAggregateIsZero() {
        let map = BASNarrativeDistortionMap(
            mapID: "empty",
            subjectRefs: [],
            distortionsBySubject: [:])
        XCTAssertEqual(map.aggregateMaxDistortion, 0)
    }

    func testNarrativeDistortionMapDominantSubjectFiltering() {
        let dist = BASNarrativeDistortion(
            distortionID: "d-x",
            realityDenial: 0.5,
            historyRewrite: 0,
            forcedClosure: 0,
            roleInversion: 0,
            urgencyMask: 0,
            confidence: 0.5)
        let map = BASNarrativeDistortionMap(
            mapID: "m-3",
            subjectRefs: ["sub-x"],
            distortionsBySubject: ["sub-x": dist],
            dominantSubjectRef: "sub-orphan")  // not in keys
        XCTAssertNil(map.dominantSubjectRef,
                     "dominant ref filtered when not in keys")
    }

    // MARK: - M462 BASSealedMemory

    func testSealedMemorySchemaVersion() {
        XCTAssertEqual(
            BASSealedMemory.currentSchemaVersion, "1.0.0")
    }

    func testSealClassCardinalityIsFour() {
        XCTAssertEqual(BASSealClass.allCases.count, 4)
    }

    func testSealClassRawValuesAreStable() {
        XCTAssertEqual(BASSealClass.midLayer.rawValue, "mid-layer")
        XCTAssertEqual(BASSealClass.deepWell.rawValue, "deep-well")
        XCTAssertEqual(BASSealClass.abyssal.rawValue, "abyssal")
        XCTAssertEqual(BASSealClass.oldSeal.rawValue, "old-seal")
    }

    func testSealDisclosureModeCardinalityIsFour() {
        XCTAssertEqual(BASSealDisclosureMode.allCases.count, 4)
    }

    func testSealDisclosureModeDefaultIsNever() {
        // Doctrine pin: Cthulhu Spec V1 §5.8 — "高敏记忆可以保留,
        // 但默认不召回". Default disclosure mode must be `.never`.
        let sealed = BASSealedMemory(
            sealedMemoryID: "sm-1",
            memoryRef: "mem-x",
            sealClass: .abyssal,
            disclosureMode: .never,
            reentryConditions: [])
        XCTAssertEqual(sealed.disclosureMode, .never)
    }

    func testSealedMemoryRoundTripCodable() throws {
        let sealed = BASSealedMemory(
            sealedMemoryID: "sm-rt",
            memoryRef: "mem-rt",
            sealClass: .oldSeal,
            disclosureMode: .sovereignWarrant,
            reentryConditions: ["audit-pass", "host-recall"])
        let data = try JSONEncoder().encode(sealed)
        let decoded = try JSONDecoder()
            .decode(BASSealedMemory.self, from: data)
        XCTAssertEqual(sealed, decoded)
    }

    // MARK: - M463 BASAbyssalPressure schema bump v1.0.0 → v1.1.0

    func testAbyssalPressureCurrentSchemaVersionIsBumped() {
        XCTAssertEqual(
            BASAbyssalPressure.currentSchemaVersion, "1.1.0",
            "M463 chapter 一百二十一 schema bump")
    }

    func testAbyssalPressureSupportedSchemaVersionsCoversBoth() {
        XCTAssertTrue(
            BASAbyssalPressure.supportedSchemaVersions.contains("1.0.0"))
        XCTAssertTrue(
            BASAbyssalPressure.supportedSchemaVersions.contains("1.1.0"))
    }

    func testAbyssalPressureHostFragilityDefaultIsZero() {
        let pressure = BASAbyssalPressure(
            pressureID: "p-default",
            unknownLoad: 0.5,
            consequenceRadius: 0.5,
            evidenceDebt: 0.5,
            ontologyDistortion: 0.5,
            manipulationIndex: 0.5,
            narrativePollution: 0.5,
            recommendedModes: [])
        XCTAssertEqual(pressure.hostFragility, 0,
                       "default hostFragility = 0 for backward-compat")
    }

    func testAbyssalPressureHostFragilityClampsTo01() {
        let high = BASAbyssalPressure(
            pressureID: "p-high",
            unknownLoad: 0.5,
            consequenceRadius: 0.5,
            evidenceDebt: 0.5,
            ontologyDistortion: 0.5,
            manipulationIndex: 0.5,
            narrativePollution: 0.5,
            recommendedModes: [],
            hostFragility: 1.5)
        XCTAssertEqual(high.hostFragility, 1.0,
                       "clamped to upper bound")
        let low = BASAbyssalPressure(
            pressureID: "p-low",
            unknownLoad: 0.5,
            consequenceRadius: 0.5,
            evidenceDebt: 0.5,
            ontologyDistortion: 0.5,
            manipulationIndex: 0.5,
            narrativePollution: 0.5,
            recommendedModes: [],
            hostFragility: -0.5)
        XCTAssertEqual(low.hostFragility, 0,
                       "clamped to lower bound")
    }

    /// Backward-compat: v1.0.0 JSON without `hostFragility`
    /// field decodes successfully with default 0.
    func testAbyssalPressureV1Point0DecodesWithDefault() throws {
        let v1Json = """
        {
          "schemaVersion": "1.0.0",
          "pressureID": "v1-pressure",
          "unknownLoad": 0.3,
          "consequenceRadius": 0.4,
          "evidenceDebt": 0.5,
          "ontologyDistortion": 0.6,
          "manipulationIndex": 0.7,
          "narrativePollution": 0.8,
          "recommendedModes": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder()
            .decode(BASAbyssalPressure.self, from: v1Json)
        XCTAssertEqual(decoded.schemaVersion, "1.0.0")
        XCTAssertEqual(decoded.hostFragility, 0,
                       "v1.0.0 baseline → hostFragility default 0")
    }

    /// Forward-compat: v1.1.0 JSON with hostFragility decodes.
    func testAbyssalPressureV1Point1DecodesField() throws {
        let v11Json = """
        {
          "schemaVersion": "1.1.0",
          "pressureID": "v11-pressure",
          "unknownLoad": 0.3,
          "consequenceRadius": 0.4,
          "evidenceDebt": 0.5,
          "ontologyDistortion": 0.6,
          "manipulationIndex": 0.7,
          "narrativePollution": 0.8,
          "recommendedModes": [],
          "hostFragility": 0.42
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder()
            .decode(BASAbyssalPressure.self, from: v11Json)
        XCTAssertEqual(decoded.schemaVersion, "1.1.0")
        XCTAssertEqual(decoded.hostFragility, 0.42, accuracy: 0.001)
    }

    /// Unsupported schema version is rejected.
    func testAbyssalPressureUnknownSchemaVersionThrows() {
        let badJson = """
        {
          "schemaVersion": "9.9.9",
          "pressureID": "bad",
          "unknownLoad": 0,
          "consequenceRadius": 0,
          "evidenceDebt": 0,
          "ontologyDistortion": 0,
          "manipulationIndex": 0,
          "narrativePollution": 0,
          "recommendedModes": []
        }
        """.data(using: .utf8)!
        XCTAssertThrowsError(
            try JSONDecoder().decode(BASAbyssalPressure.self, from: badJson))
    }

    /// Aggregate magnitude doctrine: 6-field mean preserved for
    /// backward-compat with M303/M318/M384/M398 contracts. The
    /// 7-field spec-canonical mean is exposed separately via
    /// `aggregateMagnitudeWithFragility`.
    func testAbyssalPressureAggregateMagnitudeBackwardCompat() {
        let pressure = BASAbyssalPressure(
            pressureID: "p-agg",
            unknownLoad: 1.0,
            consequenceRadius: 1.0,
            evidenceDebt: 1.0,
            ontologyDistortion: 1.0,
            manipulationIndex: 1.0,
            narrativePollution: 1.0,
            recommendedModes: [],
            hostFragility: 0)  // hostFragility NOT in 6-field mean
        XCTAssertEqual(pressure.aggregateMagnitude, 1.0,
                       accuracy: 0.0001,
                       "6-field mean preserved (M303/M318/M384/M398 contract)")
    }

    func testAbyssalPressureAggregateMagnitudeWithFragility() {
        let pressure = BASAbyssalPressure(
            pressureID: "p-agg7",
            unknownLoad: 1.0,
            consequenceRadius: 1.0,
            evidenceDebt: 1.0,
            ontologyDistortion: 1.0,
            manipulationIndex: 1.0,
            narrativePollution: 1.0,
            recommendedModes: [],
            hostFragility: 1.0)
        XCTAssertEqual(pressure.aggregateMagnitudeWithFragility,
                       1.0, accuracy: 0.0001,
                       "all-1 with fragility = 7/7 = 1.0")
        let onlyFragility = BASAbyssalPressure(
            pressureID: "p-half",
            unknownLoad: 0,
            consequenceRadius: 0,
            evidenceDebt: 0,
            ontologyDistortion: 0,
            manipulationIndex: 0,
            narrativePollution: 0,
            recommendedModes: [],
            hostFragility: 0.7)
        XCTAssertEqual(onlyFragility.aggregateMagnitudeWithFragility,
                       0.7 / 7.0, accuracy: 0.0001,
                       "hostFragility-only contribution = 1/7 weight")
        XCTAssertEqual(onlyFragility.aggregateMagnitude, 0,
                       "6-field mean ignores hostFragility")
    }
}
