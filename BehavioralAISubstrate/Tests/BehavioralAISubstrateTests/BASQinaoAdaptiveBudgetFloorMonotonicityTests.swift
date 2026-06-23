// MARK: - QINAO Substrate-100 gate #29 — adaptive_budget_floor_monotonicity
//
// HIGH: over the full BASAdaptiveRuntimeMatrixRequest grid, each produced
// budget respects its per-class floor (contextDepth/loops/candidates ≥ floor)
// and is monotone in pressure.
//
// Floors are read verbatim from AdaptiveRuntimeCore.swift:
//   contextBudget minimumBudget — primary 160 / comparative 220 /
//   reflective 260 / selection 140 (the `max(minimumBudget, …)` clamp in
//   `contextBudget(for:…)`); toolCallBudget and retrievalItemBudget are
//   `max(0, …)` floored. Monotonicity axis = requested runtimeGear
//   (.low ≤ .balanced ≤ .high) holding every other request field equal:
//   base contextBudget is non-decreasing in gear and all penalties are
//   gear-independent, so the produced contextBudget must be non-decreasing.

import XCTest
@testable import BASRuntimeCore

final class BASQinaoAdaptiveBudgetFloorMonotonicityTests: XCTestCase {

    func test_qinao_adaptive_budget_floor_monotonicity() {
        // Per-class contextBudget floor — verbatim from the
        // `minimumBudget` switch in contextBudget(for:gear:…).
        func contextFloor(_ kind: BASAdaptiveTraceKind) -> Int {
            switch kind {
            case .primary: return 160
            case .comparative: return 220
            case .reflective: return 260
            case .selection: return 140
            }
        }

        let gears: [BASRuntimeGear] = [.low, .balanced, .high]
        let environments: [BASEnvironmentClass] = [
            .simulator, .lowPower, .memoryConstrained, .normal
        ]
        let devices: [BASDevicePerformanceClass] = [
            .simulator, .memoryConstrainedPhone, .balancedPhone, .fullPhone
        ]
        let languages: [BASLanguageMode] = [
            .english, .chinese, .mixed, .unknown
        ]
        let fallbackOptions: [Bool] = [true, false]
        // Three model-invocation maps spanning all-off, all-on, and a mixed
        // per-kind setting so the non-model floor branch is exercised too.
        let invocationMaps: [[BASAdaptiveTraceKind: Bool]] = [
            [.primary: false, .comparative: false, .reflective: false, .selection: false],
            [.primary: true, .comparative: true, .reflective: true, .selection: true],
            [.primary: false, .comparative: true, .reflective: true, .selection: false]
        ]

        // Compute the grid size from the loops (do NOT hard-code).
        let expectedCells =
            gears.count *
            environments.count *
            devices.count *
            languages.count *
            fallbackOptions.count *
            invocationMaps.count
        XCTAssertGreaterThanOrEqual(
            expectedCells, 3 * 4 * 4 * 4 * 2 * 3,
            "Grid enumeration regressed below the computed cell count."
        )

        var cellsChecked = 0
        var floorAssertions = 0
        var monotoneAssertions = 0

        // 1) FLOOR: every produced budget over the full grid respects its
        //    per-class floor.
        for env in environments {
            for device in devices {
                for language in languages {
                    for fallbacks in fallbackOptions {
                        for invocation in invocationMaps {
                            for gear in gears {
                                let matrix = BASAdaptiveRuntimeMatrixResolver.resolve(
                                    request: BASAdaptiveRuntimeMatrixRequest(
                                        runtimeGear: gear,
                                        environmentClass: env,
                                        deviceClass: device,
                                        languageMode: language,
                                        allowFallbacks: fallbacks,
                                        allowsModelInvocationByKind: invocation
                                    )
                                )
                                cellsChecked += 1
                                for kind in BASAdaptiveTraceKind.allCases {
                                    let strategy = matrix.strategy(for: kind)
                                    let floor = contextFloor(kind)
                                    XCTAssertGreaterThanOrEqual(
                                        strategy.contextBudget, floor,
                                        "contextBudget below per-class floor for " +
                                        "\(kind) at gear=\(gear) env=\(env) " +
                                        "device=\(device) lang=\(language) " +
                                        "fallbacks=\(fallbacks)"
                                    )
                                    XCTAssertGreaterThanOrEqual(
                                        strategy.toolCallBudget, 0,
                                        "toolCallBudget (loops) below floor for \(kind)"
                                    )
                                    XCTAssertGreaterThanOrEqual(
                                        strategy.retrievalItemBudget, 0,
                                        "retrievalItemBudget (candidates) below floor for \(kind)"
                                    )
                                    floorAssertions += 1
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2) MONOTONICITY: holding env/device/language/fallbacks/invocation
        //    fixed, contextBudget must be non-decreasing as requested gear
        //    rises low → balanced → high (less pressure ⇒ not-smaller budget).
        for env in environments {
            for device in devices {
                for language in languages {
                    for fallbacks in fallbackOptions {
                        for invocation in invocationMaps {
                            func budgets(_ gear: BASRuntimeGear) -> [BASAdaptiveTraceKind: Int] {
                                let matrix = BASAdaptiveRuntimeMatrixResolver.resolve(
                                    request: BASAdaptiveRuntimeMatrixRequest(
                                        runtimeGear: gear,
                                        environmentClass: env,
                                        deviceClass: device,
                                        languageMode: language,
                                        allowFallbacks: fallbacks,
                                        allowsModelInvocationByKind: invocation
                                    )
                                )
                                return Dictionary(
                                    uniqueKeysWithValues: BASAdaptiveTraceKind.allCases.map {
                                        ($0, matrix.strategy(for: $0).contextBudget)
                                    }
                                )
                            }
                            let low = budgets(.low)
                            let balanced = budgets(.balanced)
                            let high = budgets(.high)
                            for kind in BASAdaptiveTraceKind.allCases {
                                let l = low[kind]!
                                let b = balanced[kind]!
                                let h = high[kind]!
                                XCTAssertLessThanOrEqual(
                                    l, b,
                                    "contextBudget not monotone low→balanced for " +
                                    "\(kind) env=\(env) device=\(device) lang=\(language)"
                                )
                                XCTAssertLessThanOrEqual(
                                    b, h,
                                    "contextBudget not monotone balanced→high for " +
                                    "\(kind) env=\(env) device=\(device) lang=\(language)"
                                )
                                monotoneAssertions += 1
                            }
                        }
                    }
                }
            }
        }

        // 3) DETERMINISM: re-resolving an identical request yields an equal
        //    matrix (Equatable on the value type).
        let probeRequest = BASAdaptiveRuntimeMatrixRequest(
            runtimeGear: .high,
            environmentClass: .normal,
            deviceClass: .fullPhone,
            languageMode: .english,
            allowFallbacks: true,
            allowsModelInvocationByKind: [
                .primary: true, .comparative: true, .reflective: true, .selection: true
            ]
        )
        let first = BASAdaptiveRuntimeMatrixResolver.resolve(request: probeRequest)
        let second = BASAdaptiveRuntimeMatrixResolver.resolve(request: probeRequest)
        XCTAssertEqual(first, second, "Resolver must be deterministic for an identical request.")

        XCTAssertEqual(cellsChecked, expectedCells)
        XCTAssertEqual(floorAssertions, expectedCells * BASAdaptiveTraceKind.allCases.count)
        XCTAssertGreaterThan(monotoneAssertions, 0)

        print("QINAO-GATE adaptive_budget_floor_monotonicity: PASS " +
              "(cells=\(cellsChecked), floor-asserts=\(floorAssertions), " +
              "monotone-asserts=\(monotoneAssertions))")
    }
}
