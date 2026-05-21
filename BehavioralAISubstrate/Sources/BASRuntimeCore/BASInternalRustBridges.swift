// MARK: - BASInternalRustBridges
// post-chapter 七百七十三 / post-XCFramework-rebuild activation
//
// Activates the 5 internal-only Rust crates' FFI surface in Swift
// via @_silgen_name declarations。 These crates ship without a
// hand-curated public C header (because their callers are internal
// substrate code,not 3rd-party C consumers):
//
//   - bas-lease-life       (chapter 七百六十二)
//   - bas-mirror-blade     (chapter 七百六十四)
//   - bas-presence-eye     (chapter 七百六十六)
//   - bas-host-constitution (chapter 七百六十八 + 七百六十九)
//   - bas-world-prior      (chapter 七百七十一)
//
// All 5 crates' #[no_mangle] extern "C" symbols ARE in the
// XCFramework staticlib (bundled via force-link anchors in
// bas-memory-usage-tracker/src/force_link.rs)。 This file just
// declares them on the Swift side so callers can invoke them
// without going through a C header bundle change。
//
// ## Why @_silgen_name + not import
//
// The XCFramework umbrella module map only declares the 3 hand-
// curated public C headers (sovereign-c-abi, red-team-bench,
// integrity-sentinel)。 Adding all 8 to the umbrella would mix
// 「3rd-party-facing API」 and「internal bridge API」 in one
// module — confusing for SDK consumers。
//
// @_silgen_name binds Swift names to the underlying linked
// symbol without requiring a C declaration。 The .a archives in
// the XCFramework slices provide the symbols;the linker resolves
// them at consumer-target link time。
//
// ## ADR-014 OPT-IN preserved
//
// All wrappers are PASSTHROUGH:they call the Rust function and
// return the result。 No production code path is changed by this
// file。 Callers that want the Rust path opt in by calling these
// wrappers;callers that don't keep using their existing Swift
// V1 implementations。 The 5-axis comparison + flip decisions
// per crate land separately,not here。

import Foundation

#if os(iOS) || os(macOS)

// MARK: - bas-lease-life (L1 lung state + breath scheduler)

@_silgen_name("bas_lease_life_abi_version")
private func _bas_lease_life_abi_version() -> Int32

@_silgen_name("bas_lung_state_decay")
private func _bas_lung_state_decay(
    _ prevPressure: Double,
    _ idleSeconds: Double,
    _ timeConstantSeconds: Double
) -> Double

@_silgen_name("bas_lung_state_record_turn")
private func _bas_lung_state_record_turn(
    _ prevPressure: Double,
    _ idleSeconds: Double,
    _ timeConstantSeconds: Double,
    _ runMode: UInt8,
    _ durationSeconds: Double
) -> Double

@_silgen_name("bas_breath_validate")
private func _bas_breath_validate(
    _ classByte: UInt8,
    _ guardLevelByte: UInt8
) -> Int32

@_silgen_name("bas_breath_should_cancel_on_reconcile")
private func _bas_breath_should_cancel_on_reconcile(
    _ classByte: UInt8,
    _ newGuardLevelByte: UInt8
) -> Int32

/// Typed Swift wrappers for the bas-lease-life crate。 All
/// methods are pure-fn pass-throughs;the actor-isolated mutable
/// accumulator state stays Swift on the host side。
public enum BASLeaseLifeBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_lease_life_abi_version()
    }

    /// p_next = clamp01(p_prev * exp(-idle / tau))
    public static func lungStateDecay(
        prevPressure: Double,
        idleSeconds: Double,
        timeConstantSeconds: Double
    ) -> Double {
        return _bas_lung_state_decay(
            prevPressure, idleSeconds, timeConstantSeconds)
    }

    /// Combined decay + turn-record step。 RunMode discriminants:
    /// 0=Dormant,1=Pulse,2=Sentinel,3=Engage,4=Reflect,
    /// 5=DeepLoop,6=Guard,7=Recovery,8=Quarantine,9=Lockdown。
    public static func lungStateRecordTurn(
        prevPressure: Double,
        idleSeconds: Double,
        timeConstantSeconds: Double,
        runMode: UInt8,
        durationSeconds: Double
    ) -> Double {
        return _bas_lung_state_record_turn(
            prevPressure, idleSeconds, timeConstantSeconds,
            runMode, durationSeconds)
    }

    /// Validate maintenance class at thermal guard level。
    /// Returns:0 ok / 1 emergency-rejects-all /
    /// 2 class-rejected-at-guard / -1 invalid byte。
    public static func breathValidate(
        classByte: UInt8, guardLevelByte: UInt8
    ) -> Int32 {
        return _bas_breath_validate(classByte, guardLevelByte)
    }

    /// Classify breath cancellation。 Returns 1 cancel / 0 keep /
    /// -1 invalid byte。
    public static func breathShouldCancelOnReconcile(
        classByte: UInt8, newGuardLevelByte: UInt8
    ) -> Int32 {
        return _bas_breath_should_cancel_on_reconcile(
            classByte, newGuardLevelByte)
    }
}

// MARK: - bas-mirror-blade (L7 decomposition state classifier)

@_silgen_name("bas_mirror_blade_abi_version")
private func _bas_mirror_blade_abi_version() -> Int32

@_silgen_name("bas_mirror_blade_classify")
private func _bas_mirror_blade_classify(
    _ emotionalLoad: Double,
    _ timePressure: Double,
    _ consequenceLevel: Double,
    _ ambiguityScore: Double,
    _ manipulationProbability: Double,
    _ relationTense: UInt8,
    _ mirrorDraftRequested: UInt8
) -> UInt8

public enum BASMirrorBladeBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_mirror_blade_abi_version()
    }

    /// Classify a context frame into a u8 bitmap of emitted
    /// DecomposeState bits:
    ///   bit 0 = FactShard (set when no other bit fires)
    ///   bit 1 = Unknown (low_confidence)
    ///   bit 2 = Contradiction (relation tense)
    ///   bit 3 = Pressure (urgency OR high_stakes)
    ///   bit 4 = Manipulation (manipulation_probability)
    ///   bit 5 = MirrorDraft (mirror_draft_requested)
    public static func classify(
        emotionalLoad: Double,
        timePressure: Double,
        consequenceLevel: Double,
        ambiguityScore: Double,
        manipulationProbability: Double,
        relationTense: Bool,
        mirrorDraftRequested: Bool
    ) -> UInt8 {
        return _bas_mirror_blade_classify(
            emotionalLoad, timePressure, consequenceLevel,
            ambiguityScore, manipulationProbability,
            relationTense ? 1 : 0,
            mirrorDraftRequested ? 1 : 0)
    }
}

// MARK: - bas-presence-eye (L6 signal-fusion classifier)

@_silgen_name("bas_presence_eye_abi_version")
private func _bas_presence_eye_abi_version() -> Int32

@_silgen_name("bas_presence_eye_fuse")
private func _bas_presence_eye_fuse(
    _ taskSalience: Double, _ taskConfidence: Double,
    _ riskSalience: Double, _ riskConfidence: Double,
    _ manipSalience: Double, _ manipConfidence: Double,
    _ envSalience: Double, _ envConfidence: Double,
    _ bodySalience: Double, _ bodyConfidence: Double
) -> Double

public enum BASPresenceEyeBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_presence_eye_abi_version()
    }

    /// Fuse 5 channel observations into a unified [0,1]
    /// confidence。 Doctrine-pinned channel weights:
    ///   task=1.0,risk=1.5,manipulation=2.0,environment=0.5,
    ///   bodyRhythm=0.75。
    /// Channels with both salience=0 AND confidence=0 are
    /// treated as「no observation」 and skipped。
    public static func fuse(
        taskSalience: Double, taskConfidence: Double,
        riskSalience: Double, riskConfidence: Double,
        manipulationSalience: Double, manipulationConfidence: Double,
        environmentSalience: Double, environmentConfidence: Double,
        bodyRhythmSalience: Double, bodyRhythmConfidence: Double
    ) -> Double {
        return _bas_presence_eye_fuse(
            taskSalience, taskConfidence,
            riskSalience, riskConfidence,
            manipulationSalience, manipulationConfidence,
            environmentSalience, environmentConfidence,
            bodyRhythmSalience, bodyRhythmConfidence)
    }
}

// MARK: - bas-host-constitution (L5 merge + deletion logic)

@_silgen_name("bas_host_constitution_abi_version")
private func _bas_host_constitution_abi_version() -> Int32

@_silgen_name("bas_host_constitution_resolve_field")
private func _bas_host_constitution_resolve_field(
    _ fieldKindByte: UInt8,
    _ valuesEqual: UInt8,
    _ leftRolledBack: UInt8,
    _ rightRolledBack: UInt8
) -> Int32

@_silgen_name("bas_host_constitution_default_strategy")
private func _bas_host_constitution_default_strategy(
    _ fieldKindByte: UInt8
) -> Int32

@_silgen_name("bas_host_constitution_classify_deletion")
private func _bas_host_constitution_classify_deletion(
    _ deletionTypeByte: UInt8,
    _ isRollbackAnchor: UInt8,
    _ isVaultGenesis: UInt8,
    _ targetsImmutableField: UInt8
) -> Int32

public enum BASHostConstitutionBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_host_constitution_abi_version()
    }

    /// Resolve a single-field merge outcome。 Returns:
    ///   0 = Success / 1 = ConflictEscalated /
    ///   2 = RollbackBlocked / -1 = invalid field kind
    /// FieldKind discriminants (0..10):IdentityTags / TonePreference /
    /// LongTermGoals / NoGoZones / RiskThresholds / MemoryPermissions /
    /// WorkRoutines / RelationshipRefs / StyleConstraints /
    /// UpdatePolicy / ActiveVersion。
    public static func resolveField(
        fieldKindByte: UInt8,
        valuesEqual: Bool,
        leftRolledBack: Bool,
        rightRolledBack: Bool
    ) -> Int32 {
        return _bas_host_constitution_resolve_field(
            fieldKindByte,
            valuesEqual ? 1 : 0,
            leftRolledBack ? 1 : 0,
            rightRolledBack ? 1 : 0)
    }

    /// Returns the default MergeStrategy u8 discriminant for the
    /// field kind:0=KeepLeft / 1=KeepRight / 2=Union /
    /// 3=NumericMin / 4=NumericMax / 5=FailOnConflict /
    /// -1=invalid。
    public static func defaultStrategy(
        fieldKindByte: UInt8
    ) -> Int32 {
        return _bas_host_constitution_default_strategy(fieldKindByte)
    }

    /// Classify deletion eligibility。 Returns:
    ///   0 = Allowed / 1 = BlockedByRollbackAnchor /
    ///   2 = BlockedByVaultGenesis /
    ///   3 = BlockedByImmutableField / -1 = invalid deletion type
    /// DeletionType discriminants:0=Cascade / 1=Selective / 2=Rollback。
    public static func classifyDeletion(
        deletionTypeByte: UInt8,
        isRollbackAnchor: Bool,
        isVaultGenesis: Bool,
        targetsImmutableField: Bool
    ) -> Int32 {
        return _bas_host_constitution_classify_deletion(
            deletionTypeByte,
            isRollbackAnchor ? 1 : 0,
            isVaultGenesis ? 1 : 0,
            targetsImmutableField ? 1 : 0)
    }
}

// MARK: - bas-world-prior (L4 typed surface + pure fns)

@_silgen_name("bas_world_prior_abi_version")
private func _bas_world_prior_abi_version() -> Int32

@_silgen_name("bas_world_prior_propagate_evidence")
private func _bas_world_prior_propagate_evidence(
    _ levels: UnsafePointer<UInt8>?,
    _ len: Int32
) -> Int32

@_silgen_name("bas_world_prior_aggregate_latency")
private func _bas_world_prior_aggregate_latency(
    _ latencies: UnsafePointer<Int64>?,
    _ len: Int32
) -> Int64

@_silgen_name("bas_world_prior_worst_reversibility")
private func _bas_world_prior_worst_reversibility(
    _ values: UnsafePointer<UInt8>?,
    _ len: Int32
) -> Int32

public enum BASWorldPriorBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_world_prior_abi_version()
    }

    /// Weakest-link evidence propagation。 EvidenceLevel
    /// discriminants:0=Anecdotal / 1=Observed /
    /// 2=PeerReviewed / 3=Mechanistic。 Returns the minimum
    /// (weakest) level,or -1 on invalid byte。 Empty input
    /// → 0 (Anecdotal,weakest)。
    public static func propagateEvidence(
        levels: [UInt8]
    ) -> Int32 {
        if levels.isEmpty {
            return 0 // Anecdotal
        }
        return levels.withUnsafeBufferPointer { buf in
            _bas_world_prior_propagate_evidence(
                buf.baseAddress, Int32(buf.count))
        }
    }

    /// Integer mean of a list of latency_ms values。 Empty →
    /// 0;negative len → -1。
    public static func aggregateLatency(
        latencies: [Int64]
    ) -> Int64 {
        if latencies.isEmpty {
            return 0
        }
        return latencies.withUnsafeBufferPointer { buf in
            _bas_world_prior_aggregate_latency(
                buf.baseAddress, Int32(buf.count))
        }
    }

    /// Worst-case (most dangerous) reversibility。
    /// Reversibility discriminants:0=Irreversible / 1=Hard /
    /// 2=Medium / 3=Easy。 Returns the minimum (worst),or -1
    /// on invalid byte。 Empty → 3 (Easy,least dangerous)。
    public static func worstReversibility(
        values: [UInt8]
    ) -> Int32 {
        if values.isEmpty {
            return 3 // Easy
        }
        return values.withUnsafeBufferPointer { buf in
            _bas_world_prior_worst_reversibility(
                buf.baseAddress, Int32(buf.count))
        }
    }
}

#endif  // os(iOS) || os(macOS)
