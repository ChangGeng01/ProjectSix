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

// MARK: - bas-shadow-trial (L13 Phase 2 state machine)

@_silgen_name("bas_shadow_trial_abi_version")
private func _bas_shadow_trial_abi_version() -> Int32

/// chapter 七百七十四 ABI note:Rust signature takes i32 (not u8)
/// to sidestep a Swift @_silgen_name calling-convention quirk
/// where two consecutive variable UInt8 args don't reliably
/// zero-extend across registers on ARM64。 The Swift wrapper
/// converts UInt8 → Int32 at the call site to keep the public
/// surface byte-shaped。
@_silgen_name("bas_shadow_trial_transition")
private func _bas_shadow_trial_transition(
    _ currentPhase: Int32,
    _ verdict: Int32
) -> Int32

public enum BASShadowTrialBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_shadow_trial_abi_version()
    }

    /// Decoded transition result。 Mirrors Rust's `TransitionResult`
    /// struct,but unpacks the packed-i32 wire format。
    public struct Result: Equatable, Hashable, Sendable {
        /// 0=AdvanceTo / 1=RejectedTerminal / 2=RejectedUnknownVerdict
        public let outcome: Int32
        /// Next phase byte (0..3 per ShadowTrialPhase discriminants)
        public let nextPhaseByte: UInt8
        /// True iff outcome == 0 (AdvanceTo)。
        public var advanced: Bool { outcome == 0 }
    }

    /// Invoke the Rust state-machine transition。
    ///
    /// Phase discriminants:0=Nursery / 1=TrialInFlight /
    /// 2=Sealed / 3=Retracted。
    /// Verdict discriminants:0=Passed / 1=Failed / 2=Blocked /
    /// 3=Nil (no verdict) / any-other=Unknown。
    ///
    /// Returns Result(outcome: -1, nextPhaseByte: 0) on invalid
    /// phase byte。
    public static func transition(
        currentPhaseByte: UInt8,
        verdictByte: UInt8
    ) -> Result {
        let packed = _bas_shadow_trial_transition(
            Int32(currentPhaseByte), Int32(verdictByte))
        if packed < 0 {
            return Result(outcome: -1, nextPhaseByte: 0)
        }
        let outcome = packed & 0x0F
        let nextPhase = UInt8((packed >> 4) & 0x0F)
        return Result(outcome: outcome, nextPhaseByte: nextPhase)
    }
}

// MARK: - bas-world-prior (L4 typed surface + pure fns)

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

// MARK: - bas-atom-lifecycle (L8 memory atom state machine)
// chapter 七百八十三 / M2566

@_silgen_name("bas_atom_lifecycle_abi_version")
private func _bas_atom_lifecycle_abi_version() -> Int32

@_silgen_name("bas_atom_lifecycle_transition")
private func _bas_atom_lifecycle_transition(
    _ currentPhase: Int32,
    _ action: Int32
) -> Int32

public enum BASAtomLifecycleBridge {
    public static let abiVersion: Int32 = 1

    public static func liveAbiVersion() -> Int32 {
        return _bas_atom_lifecycle_abi_version()
    }

    public struct Result: Equatable, Hashable, Sendable {
        /// 0=AdvanceTo / 1=RejectedIllegal / 2=RejectedTerminal
        public let outcome: Int32
        /// Next phase byte (0..4 per AtomPhase discriminants)。
        public let nextPhaseByte: UInt8
        public var advanced: Bool { outcome == 0 }
    }

    /// Invoke the Rust atom-lifecycle state-machine transition。
    ///
    /// Phase discriminants:0=Created / 1=Admitted / 2=Linked /
    /// 3=Archived / 4=Tombstoned。
    /// Action discriminants:0=Admit / 1=Link / 2=Archive / 3=Tombstone。
    ///
    /// Returns Result(outcome: -1, nextPhaseByte: 0) on invalid byte。
    public static func transition(
        currentPhaseByte: UInt8,
        actionByte: UInt8
    ) -> Result {
        let packed = _bas_atom_lifecycle_transition(
            Int32(currentPhaseByte), Int32(actionByte))
        if packed < 0 {
            return Result(outcome: -1, nextPhaseByte: 0)
        }
        let outcome = packed & 0x0F
        let nextPhase = UInt8((packed >> 4) & 0x0F)
        return Result(outcome: outcome, nextPhaseByte: nextPhase)
    }
}

// MARK: - bas-agent-fabric (Agent Fabric merge engine kernels)
// chapter 九百五十六.9 / M3485.9 — wire the Rust crate into Swift。
// Per user directive「继续 提高 ... rust ... 比例」。

@_silgen_name("bas_agent_fabric_abi_version")
private func _bas_agent_fabric_abi_version() -> Int32

@_silgen_name("bas_agent_fabric_fnv1a64")
private func _bas_agent_fabric_fnv1a64(
    _ ptr: UnsafePointer<UInt8>?,
    _ len: Int
) -> UInt64

@_silgen_name("bas_agent_fabric_strong_merge_id")
private func _bas_agent_fabric_strong_merge_id(
    _ turnIDPtr: UnsafePointer<Int8>?,
    _ turnIDLen: Int,
    // chapter 九百五十六.11 USER-PASS-4 H3 fix:renamed from
    // `deltaIDsConcatPtr` / `*Len` (v1 null-separated leftover)。
    // v2+ uses length-prefixed buffer encoding。 Names now match
    // Rust signature `delta_ids_buf_ptr` / `delta_ids_buf_len`。
    _ deltaIDsBufPtr: UnsafePointer<Int8>?,
    _ deltaIDsBufLen: Int,
    _ deltaCount: Int,
    _ outPtr: UnsafeMutablePointer<UInt8>?,
    _ outCap: Int,
    _ outRequired: UnsafeMutablePointer<Int>?
) -> Int

/// Typed Swift wrappers for the bas-agent-fabric crate。 All
/// methods are pure-fn pass-throughs。 Production use sites can
/// flip from the Swift body to the Rust body by changing the
/// caller (the Swift body is preserved in the call site per 红线
/// 7 + ADR-014 OPT-IN)。
public enum BASAgentFabricBridge {
    /// Pinned ABI version。 Swift-side sanity check that the
    /// XCFramework binary's ABI matches what this Swift bridge
    /// expects。 Mismatch ⇒ rebuild XCFramework OR roll Swift back。
    ///
    /// History:
    ///   - 1 = ch 956.9 initial (null-separated deltaID encoding)
    ///   - 2 = ch 956.10 USER-PASS gap #3 fix (length-prefixed
    ///         deltaID encoding,admits any byte sequence including
    ///         embedded NUL bytes)
    ///   - 3 = ch 956.11 USER-PASS-4 H2 fix (DoS bounds:
    ///         delta_count ≤ 100k,per-ID len ≤ 1M,
    ///         buf ≤ isize::MAX,checked_add cursor arithmetic)
    public static let abiVersion: Int32 = 3

    /// Read the ABI version actually compiled into the linked
    /// Rust staticlib。 Test code asserts `abiVersion == liveAbiVersion()`。
    public static func liveAbiVersion() -> Int32 {
        return _bas_agent_fabric_abi_version()
    }

    /// Result codes for `strongMergeID` failures。 Mirrors Rust
    /// FFI return values per ch 956.10 USER-PASS gap #3 fix。
    public enum BridgeError: Error, Equatable, Sendable {
        /// Output buffer too small (should not happen via the
        /// typed bridge — two-pass capacity discovery prevents it)
        case bufferTooSmall(required: Int)
        /// UTF-8 decode failure in input (impossible for Swift
        /// String inputs — guard exists for FFI safety)
        case malformedUTF8
        /// Length-prefix protocol violation (count mismatch,
        /// truncated buffer,etc.)。 Should not happen via this
        /// bridge since it encodes correctly。
        case malformedProtocol
        /// Other negative return — unknown failure
        case unknown(code: Int)
    }

    /// FNV-1a 64-bit hash of arbitrary bytes via the Rust kernel。
    /// Byte-identical to Swift's private `BASAgentMergeEngine
    /// .fnv1a64` (ch 九百五十六.5 USER-PASS gap #4 fix) for any
    /// input — verified by cross-language parity tests。
    ///
    /// Empty input returns the FNV-1a offset basis
    /// (0xcbf29ce484222325)。 Safe for empty Data — passes nil ptr
    /// when buffer has no backing storage。
    public static func fnv1a64(_ data: Data) -> UInt64 {
        // chapter 九百五十六.10 USER-PASS gap #2 — defensive empty
        // path:Rust accepts `(nil, 0)` and returns offset basis,
        // matching the empty-Data semantics without dereferencing
        // a possibly-nil baseAddress。
        if data.isEmpty {
            return _bas_agent_fabric_fnv1a64(nil, 0)
        }
        return data.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress
            return _bas_agent_fabric_fnv1a64(ptr, data.count)
        }
    }

    public static func fnv1a64(_ s: String) -> UInt64 {
        return fnv1a64(Data(s.utf8))
    }

    /// chapter 九百五十六.10 USER-PASS gap #3 fix — encode delta
    /// IDs into the v2 length-prefixed buffer format。 Each ID:
    /// 4-byte little-endian `u32` length,then that many UTF-8
    /// bytes。 NO separator。 Admits any byte sequence including
    /// embedded NUL。 Pure function。
    private static func encodeDeltaIDsLengthPrefixed(
        _ deltaIDs: [String]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            deltaIDs.reduce(0) { $0 + 4 + $1.utf8.count })
        for id in deltaIDs {
            let bytes = Array(id.utf8)
            let len = UInt32(bytes.count).littleEndian
            withUnsafeBytes(of: len) { lenRaw in
                buf.append(contentsOf: lenRaw)
            }
            buf.append(contentsOf: bytes)
        }
        return buf
    }

    /// Build the canonical mergeID via the Rust kernel。
    /// Byte-identical to Swift's private `BASAgentMergeEngine
    /// .strongMergeID(turnID:deltaIDs:)` (ch 九百五十六.5 USER-PASS
    /// gap #4 fix)。 Returns `merge.<turnID>.<count>.<hex16>`。
    ///
    /// Per ch 956.10 USER-PASS gap #2:safe for empty `turnID`
    /// (no force-unwrap)。 Per ch 956.10 USER-PASS gap #3:safe
    /// for `deltaID` containing any byte including NUL
    /// (length-prefixed encoding)。
    ///
    /// Returns nil only on internal protocol violation — Swift
    /// String inputs cannot produce UTF-8 errors,so this should
    /// only be nil if the bridge is broken (caller can XCTAssert
    /// non-nil safely)。 For richer error info use `strongMergeIDOrThrow`。
    public static func strongMergeID(
        turnID: String,
        deltaIDs: [String]
    ) -> String? {
        try? strongMergeIDOrThrow(
            turnID: turnID, deltaIDs: deltaIDs)
    }

    /// Throwing variant — surfaces the exact `BridgeError` for
    /// debugging。
    public static func strongMergeIDOrThrow(
        turnID: String,
        deltaIDs: [String]
    ) throws -> String {
        let turnBytes = Array(turnID.utf8)
        let idBuf = encodeDeltaIDsLengthPrefixed(deltaIDs)
        // Pass 1: discover required capacity
        var required: Int = 0
        let probe = callStrongMergeID(
            turnBytes: turnBytes,
            idBuf: idBuf,
            deltaCount: deltaIDs.count,
            out: nil,
            outCap: 0,
            outRequired: &required)
        switch probe {
        case -2: throw BridgeError.malformedUTF8
        case -3: throw BridgeError.malformedProtocol
        default: break
        }
        // probe is either -1 (expected, since out is nil) or the
        // written-bytes count (if out_cap was big enough,which it
        // isn't since we passed 0)
        guard required > 0 else {
            throw BridgeError.unknown(code: probe)
        }
        // Pass 2: allocate + fill
        var out = [UInt8](repeating: 0, count: required)
        let written = out.withUnsafeMutableBufferPointer { ob in
            callStrongMergeID(
                turnBytes: turnBytes,
                idBuf: idBuf,
                deltaCount: deltaIDs.count,
                out: ob.baseAddress,
                outCap: ob.count,
                outRequired: nil)
        }
        switch written {
        case -1: throw BridgeError.bufferTooSmall(
            required: required)
        case -2: throw BridgeError.malformedUTF8
        case -3: throw BridgeError.malformedProtocol
        case let n where n < 0: throw BridgeError.unknown(code: n)
        default: break
        }
        guard let s = String(
            bytes: out[..<written], encoding: .utf8)
        else { throw BridgeError.malformedUTF8 }
        return s
    }

    /// chapter 九百五十六.10 USER-PASS gap #2 fix — single helper
    /// for the FFI call,with NO force-unwraps on baseAddress。
    /// Both empty turnBytes AND empty idBuf are valid (Rust side
    /// handles nil + zero len)。
    private static func callStrongMergeID(
        turnBytes: [UInt8],
        idBuf: [UInt8],
        deltaCount: Int,
        out: UnsafeMutablePointer<UInt8>?,
        outCap: Int,
        outRequired: UnsafeMutablePointer<Int>?
    ) -> Int {
        // Safe pointer derivation:if buffer is empty,pass nil。
        // Otherwise pass baseAddress (guaranteed non-nil for
        // non-empty Array per Swift contract)。
        func withTurn<R>(
            _ body: (UnsafePointer<Int8>?, Int) -> R
        ) -> R {
            if turnBytes.isEmpty { return body(nil, 0) }
            return turnBytes.withUnsafeBufferPointer { ub in
                ub.baseAddress!.withMemoryRebound(
                    to: Int8.self, capacity: ub.count
                ) { ip in body(ip, ub.count) }
            }
        }
        func withIDs<R>(
            _ body: (UnsafePointer<Int8>?, Int) -> R
        ) -> R {
            if idBuf.isEmpty { return body(nil, 0) }
            return idBuf.withUnsafeBufferPointer { ub in
                ub.baseAddress!.withMemoryRebound(
                    to: Int8.self, capacity: ub.count
                ) { ip in body(ip, ub.count) }
            }
        }
        return withTurn { tPtr, tLen in
            withIDs { iPtr, iLen in
                Int(_bas_agent_fabric_strong_merge_id(
                    tPtr, tLen,
                    iPtr, iLen, deltaCount,
                    out, outCap, outRequired))
            }
        }
    }
}

// MARK: - BASRustABIRegistry (USER-PASS gap #1 — versioning + bloat)
//
// chapter 九百五十六.10 / M3485.10 USER-PASS gap #1 fix:explicit
// ABI registry + bloat audit infrastructure。 Per user's observation:
// "Rust 现在通过 BASRustMemoryTracker.xcframework 聚合所有符号,
// 这个 umbrella binary 会越来越重,后面要管 ABI 版本和符号膨胀。"
//
// What this provides:
//   - Per-crate ABI version snapshot (Swift-side expected values)
//   - Liveness probes (calls each crate's bas_<name>_abi_version
//     extern "C" fn,asserts match)
//   - Binary size budget check — read the linked staticlib's size
//     from disk + fail tests if it exceeds budget
//
// Per chapter 七百四 / M2191 force-link discipline:every crate
// in the umbrella has a `bas_<crate>_abi_version()` symbol。 The
// registry below tracks the Swift-side EXPECTED values for all
// of them and the bundle's total crate count。

@_silgen_name("bas_substrate_bundle_crate_count")
internal func _bas_substrate_bundle_crate_count() -> Int32

/// Per-crate ABI version registry。 Swift-side EXPECTED values。
/// Drift between expected (this enum) and live (Rust call) is
/// CRITICAL — fix by rebuilding XCFramework or rolling Swift back。
public enum BASRustABIRegistry {

    /// Total crate count in the umbrella XCFramework。 Bumped
    /// every time `bas-memory-usage-tracker` adds a new path dep
    /// in `Cargo.toml` AND adds the force-link anchor in
    /// `src/force_link.rs`。
    public static let expectedBundleCrateCount: Int32 = 24

    /// Read the live bundle crate count from the linked staticlib。
    public static func liveBundleCrateCount() -> Int32 {
        return _bas_substrate_bundle_crate_count()
    }

    /// One per-crate ABI-version probe — pairs a Swift-side
    /// expected value with a closure that reads the live value
    /// from the linked Rust staticlib。 chapter 九百五十六.11
    /// USER-PASS-4 H1 fix:turn the previously decorative
    /// `perCrateExpected` dict into an actual table that
    /// `auditMismatches()` iterates。 Without closures the dict
    /// was useless — adding a row did nothing。
    public struct ABIProbe: Sendable {
        public let crateName: String
        public let expected: Int32
        public let liveProbe: @Sendable () -> Int32
    }

    /// Registered per-crate expected ABI versions + live probes。
    /// Add a row when a crate's `bas_<name>_abi_version()` would
    /// CHANGE — bump in Rust + bump in this table simultaneously。
    /// Each row's `liveProbe` MUST point at the corresponding
    /// Swift bridge's `liveAbiVersion()` (which calls the
    /// `@_silgen_name`-declared extern "C" symbol)。
    ///
    /// Currently tracked:bas-agent-fabric。 Future revisions can
    /// absorb other crates (bas-lease-life,bas-mirror-blade,etc.)
    /// when their Swift bridge enums expose `liveAbiVersion()`。
    public static let probes: [ABIProbe] = [
        ABIProbe(
            crateName: "bas-agent-fabric",
            expected: BASAgentFabricBridge.abiVersion,
            liveProbe: {
                BASAgentFabricBridge.liveAbiVersion()
            }),
    ]

    /// Run ALL registered ABI probes,return mismatches。 Empty
    /// result = all match。 Test code asserts result.isEmpty。
    public static func auditMismatches() -> [String] {
        var mismatches: [String] = []
        let liveBundle = liveBundleCrateCount()
        if liveBundle != expectedBundleCrateCount {
            mismatches.append(
                "bundle.crate_count expected=" +
                "\(expectedBundleCrateCount) live=\(liveBundle)")
        }
        // chapter 九百五十六.11 USER-PASS-4 H1 fix:actually
        // iterate the probes table。 Previously hardcoded one
        // crate's check;the `perCrateExpected` dict was dead
        // code。
        for probe in probes {
            let live = probe.liveProbe()
            if live != probe.expected {
                mismatches.append(
                    "\(probe.crateName) expected=" +
                    "\(probe.expected) live=\(live)")
            }
        }
        return mismatches
    }

    /// Soft budget for the XCFramework staticlib slice in bytes。
    /// chapter 九百五十六.11 USER-PASS-4 H4 fix:corrected from
    /// stale "~30 MB" doc — actual measured size is ~22 MB per
    /// slice (post ch 956.11)。 60 MB ceiling gives ~2.7× headroom
    /// for crate growth + catches accidental ballooning。
    public static let perSliceBytesBudget: Int = 60 * 1024 * 1024
}

#endif  // os(iOS) || os(macOS)
