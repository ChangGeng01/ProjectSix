// MARK: - BASMambaTrainingValidator — chapter 四百 / M917
//
// Co-located validator for `BASTrainingDatum` against the
// Mamba training schema declared in BASRuntimeCore's
// `BASMambaTrainingCorpusSchema.swift`。Lives in BASHostKit
// because `BASTrainingDatum` is defined here (next to the
// M903 exporter) — chapter 二百一一 single-source-of-truth:
// validator co-located with the type it inspects。

import Foundation
import BASRuntimeCore

public enum BASMambaTrainingValidator {

    /// Validate one `BASTrainingDatum` against the corpus
    /// schema。Returns typed result;does NOT throw (training
    /// pipelines accumulate failures across the corpus before
    /// deciding whether to abort)。
    public static func validate(
        datum: BASTrainingDatum
    ) -> BASMambaTrainingValidationResult {
        let event = datum.event

        // Required identity quintet:eventID / timestampMs /
        // kind / sessionID / sequenceNumber。Codable would
        // reject `nil` on these (they're non-Optional),so we
        // only check the string emptiness + numeric validity。
        if event.eventID.trimmingCharacters(
            in: .whitespacesAndNewlines).isEmpty
        {
            return .invalid(
                reason: .missingRequiredEventField)
        }
        if event.sessionID.isEmpty {
            return .invalid(reason: .emptySessionID)
        }
        if event.timestampMs <= 0 {
            return .invalid(
                reason: .nonPositiveTimestamp)
        }
        // Contradictory state context: caller-supplied state
        // claims to be ON (both fields populated by makeDatum
        // resolving from the store)but resolution returned nil
        // for both → state store was empty for this event,
        // which is a corpus-quality flag。Skipping in the
        // corpus is preferable to silent training on missing
        // state。
        // Note:this only fires for datums whose ORIGINAL
        // event.stateBeforeID OR stateAfterID was non-nil but
        // the resolution still came back nil。Datums with both
        // ID fields nil pass (legitimate pre-G2 events)。
        let beforeIDSet = (event.stateBeforeID?.isEmpty
            == false)
        let afterIDSet = (event.stateAfterID?.isEmpty
            == false)
        let beforeResolved = datum.stateBefore != nil
        let afterResolved = datum.stateAfter != nil
        if (beforeIDSet && !beforeResolved
            && datum.stateBefore == nil
            && datum.stateAfter == nil
            && !afterIDSet)
            || (afterIDSet && !afterResolved
                && datum.stateBefore == nil
                && datum.stateAfter == nil
                && !beforeIDSet)
        {
            // One ID field set, other nil, BOTH resolved nil
            // → contradictory state context。
            return .invalid(
                reason: .contradictoryStateContext)
        }
        return .valid
    }

    /// Convenience:validate a sequence,return the count of
    /// valid + a histogram of failure reasons。Trainers use
    /// this on corpus load to decide whether to proceed。
    public static func validate(
        corpus: [BASTrainingDatum]
    ) -> (valid: Int,
          failures: [BASMambaTrainingValidationFailure: Int])
    {
        var valid = 0
        var failures:
            [BASMambaTrainingValidationFailure: Int] = [:]
        for datum in corpus {
            switch validate(datum: datum) {
            case .valid:
                valid += 1
            case .invalid(let reason):
                failures[reason, default: 0] += 1
            }
        }
        return (valid, failures)
    }
}
