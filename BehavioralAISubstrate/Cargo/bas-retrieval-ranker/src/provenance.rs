// SPDX:internal
//
// provenance.rs — chapter 七百十三 第二刀 / M2237
//
// Per architectural matrix「Rust:Memory engine + provenance +
// integrity hash」 — typed-attestation-tier filter ported from
// Swift `BASOrganTrainedWeightFilter`。 Same structural-invariant
// decision tree:
//
//   1. trainingCorpusHashHex length must be 64
//   2. trainedWeightsHashHex length must be 64
//   3. both hash fields must be all-hex characters
//   4. tier must be ≥ domainExpertReviewed (ordinal 3)
//   5. non-production tier carrying attestation = forged-uplift
//   6. production tier without attestation = missing-attestation
//
// All decisions are pure-value with no I/O。 The Rust port lets
// host-side organ registry batch-screen 100s of envelopes in a
// single FFI call。

/// Provenance tier ladder matching Swift
/// `BASOrganTrainedWeightProvenance.Tier`。 Ordinals preserved
/// so comparisons stay aligned with the Swift sort order。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum Tier {
    Illustrative = 0,
    AiAdvisory = 1,
    PeerReviewed = 2,
    DomainExpertReviewed = 3,
}

impl Tier {
    pub fn from_ordinal(o: i32) -> Option<Tier> {
        match o {
            0 => Some(Tier::Illustrative),
            1 => Some(Tier::AiAdvisory),
            2 => Some(Tier::PeerReviewed),
            3 => Some(Tier::DomainExpertReviewed),
            _ => None,
        }
    }
    pub fn ordinal(self) -> i32 { self as i32 }
}

/// Provenance envelope — substrate-side projection of the
/// Swift `BASOrganTrainedWeightProvenance` struct。 Only the
/// fields needed for the gate decision are mirrored;the rest
/// (descriptions,timestamps,refs) stay on the Swift side。
pub struct Provenance<'a> {
    pub training_corpus_hash_hex: &'a str,
    pub trained_weights_hash_hex: &'a str,
    pub tier: Tier,
    /// `expertAttestationSignatureRef != nil`
    pub has_attestation_signature_ref: bool,
    /// `attestationIssuedAt != nil`
    pub has_attestation_issued_at: bool,
}

/// Minimum tier permitted to serve production runtime requests。
/// Matches Swift `BASOrganTrainedWeightFilter.productionTierFloor`。
pub const PRODUCTION_TIER_FLOOR: Tier =
    Tier::DomainExpertReviewed;

/// Typed rejection reasons,one-to-one with Swift
/// `BASOrganTrainedWeightFilter.Rejection`。 The C ABI encodes
/// these as i32 codes (see `rejection_code`)。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Rejection {
    MalformedHashLength {
        field: HashField,
        length: usize,
    },
    MalformedHashContent {
        field: HashField,
        first_invalid_char: char,
    },
    BelowProductionTier { tier: Tier },
    NonProductionTierCarriesAttestation,
    MissingAttestationForProductionTier,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HashField {
    TrainingCorpus,
    TrainedWeights,
}

/// Compact i32 code for the C ABI surface。
///   0       — permitted
///   1       — training_corpus malformed-length
///   2       — trained_weights malformed-length
///   3       — training_corpus malformed-content
///   4       — trained_weights malformed-content
///   5       — below_production_tier
///   6       — non_production_tier_carries_attestation
///   7       — missing_attestation_for_production_tier
pub fn rejection_code(r: Option<&Rejection>) -> i32 {
    match r {
        None => 0,
        Some(Rejection::MalformedHashLength {
            field: HashField::TrainingCorpus, .. }) => 1,
        Some(Rejection::MalformedHashLength {
            field: HashField::TrainedWeights, .. }) => 2,
        Some(Rejection::MalformedHashContent {
            field: HashField::TrainingCorpus, .. }) => 3,
        Some(Rejection::MalformedHashContent {
            field: HashField::TrainedWeights, .. }) => 4,
        Some(Rejection::BelowProductionTier { .. }) => 5,
        Some(
            Rejection::NonProductionTierCarriesAttestation
        ) => 6,
        Some(
            Rejection::MissingAttestationForProductionTier
        ) => 7,
    }
}

/// Return nil if the envelope passes the production gate;
/// otherwise the typed rejection reason matching Swift exactly。
pub fn rejection_reason(
    p: &Provenance
) -> Option<Rejection> {
    // Hash length pin first — structural invariant。
    if p.training_corpus_hash_hex.chars().count() != 64 {
        return Some(Rejection::MalformedHashLength {
            field: HashField::TrainingCorpus,
            length: p.training_corpus_hash_hex.chars().count(),
        });
    }
    if p.trained_weights_hash_hex.chars().count() != 64 {
        return Some(Rejection::MalformedHashLength {
            field: HashField::TrainedWeights,
            length: p.trained_weights_hash_hex.chars().count(),
        });
    }
    // Hash content must be hex。
    if let Some(c) = first_non_hex_char(
        p.training_corpus_hash_hex)
    {
        return Some(Rejection::MalformedHashContent {
            field: HashField::TrainingCorpus,
            first_invalid_char: c,
        });
    }
    if let Some(c) = first_non_hex_char(
        p.trained_weights_hash_hex)
    {
        return Some(Rejection::MalformedHashContent {
            field: HashField::TrainedWeights,
            first_invalid_char: c,
        });
    }
    // Tier check。
    if p.tier.ordinal() < PRODUCTION_TIER_FLOOR.ordinal() {
        if p.has_attestation_signature_ref {
            return Some(
              Rejection::NonProductionTierCarriesAttestation
            );
        }
        return Some(
            Rejection::BelowProductionTier { tier: p.tier });
    }
    // Production tier missing attestation。
    if !p.has_attestation_signature_ref
        || !p.has_attestation_issued_at
    {
        return Some(
            Rejection::MissingAttestationForProductionTier);
    }
    None
}

/// Convenience predicate。
pub fn is_permitted_for_production(p: &Provenance) -> bool {
    rejection_reason(p).is_none()
}

/// First non-hex character if any,else None。 Hex set is
/// `[0-9a-fA-F]`。 Matches Swift `Character.isHexDigit`。
pub fn first_non_hex_char(s: &str) -> Option<char> {
    for c in s.chars() {
        if !c.is_ascii_hexdigit() {
            return Some(c);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn good_hash() -> &'static str {
        // Valid 64-char lowercase hex
        "ba7816bf8f01cfea414140de5dae2223\
         b00361a396177a9cb410ff61f20015ad"
    }

    fn good_provenance() -> Provenance<'static> {
        Provenance {
            training_corpus_hash_hex: good_hash(),
            trained_weights_hash_hex: good_hash(),
            tier: Tier::DomainExpertReviewed,
            has_attestation_signature_ref: true,
            has_attestation_issued_at: true,
        }
    }

    #[test]
    fn good_provenance_permitted() {
        let p = good_provenance();
        assert!(is_permitted_for_production(&p));
        assert_eq!(rejection_reason(&p), None);
    }

    #[test]
    fn malformed_length_training_corpus() {
        let mut p = good_provenance();
        p.training_corpus_hash_hex = "short";
        let r = rejection_reason(&p);
        match r {
            Some(Rejection::MalformedHashLength {
                field: HashField::TrainingCorpus,
                length: 5,
            }) => (),
            _ => panic!("expected length-5 training-corpus"),
        }
        assert_eq!(rejection_code(r.as_ref()), 1);
    }

    #[test]
    fn malformed_length_trained_weights() {
        let mut p = good_provenance();
        p.trained_weights_hash_hex = "way-too-short";
        let r = rejection_reason(&p);
        assert_eq!(rejection_code(r.as_ref()), 2);
    }

    #[test]
    fn malformed_content_training_corpus() {
        let mut p = good_provenance();
        // 64 z's — passes length but fails content
        let bad: String = "z".repeat(64);
        p.training_corpus_hash_hex = Box::leak(
            bad.into_boxed_str());
        let r = rejection_reason(&p);
        match r {
            Some(Rejection::MalformedHashContent {
                field: HashField::TrainingCorpus,
                first_invalid_char: 'z',
            }) => (),
            _ => panic!("expected content rejection"),
        }
        assert_eq!(rejection_code(r.as_ref()), 3);
    }

    #[test]
    fn malformed_content_trained_weights() {
        let mut p = good_provenance();
        let bad: String = "G".to_string() + &"a".repeat(63);
        p.trained_weights_hash_hex = Box::leak(
            bad.into_boxed_str());
        let r = rejection_reason(&p);
        assert_eq!(rejection_code(r.as_ref()), 4);
    }

    #[test]
    fn below_production_tier_no_attestation() {
        let mut p = good_provenance();
        p.tier = Tier::PeerReviewed;
        p.has_attestation_signature_ref = false;
        p.has_attestation_issued_at = false;
        let r = rejection_reason(&p);
        match r {
            Some(Rejection::BelowProductionTier {
                tier: Tier::PeerReviewed }) => (),
            _ => panic!("expected below-tier"),
        }
        assert_eq!(rejection_code(r.as_ref()), 5);
    }

    #[test]
    fn non_production_tier_carrying_attestation_is_flagged() {
        let mut p = good_provenance();
        p.tier = Tier::AiAdvisory;
        // attestation still set — forged-uplift attempt
        let r = rejection_reason(&p);
        match r {
            Some(
                Rejection::NonProductionTierCarriesAttestation
            ) => (),
            _ => panic!("expected forged-uplift signal"),
        }
        assert_eq!(rejection_code(r.as_ref()), 6);
    }

    #[test]
    fn production_tier_missing_attestation_ref() {
        let mut p = good_provenance();
        p.has_attestation_signature_ref = false;
        let r = rejection_reason(&p);
        match r {
            Some(
                Rejection::MissingAttestationForProductionTier
            ) => (),
            _ => panic!("expected missing-attestation"),
        }
        assert_eq!(rejection_code(r.as_ref()), 7);
    }

    #[test]
    fn production_tier_missing_attestation_timestamp() {
        let mut p = good_provenance();
        p.has_attestation_issued_at = false;
        let r = rejection_reason(&p);
        assert_eq!(rejection_code(r.as_ref()), 7);
    }

    #[test]
    fn uppercase_hex_accepted() {
        let mut p = good_provenance();
        let upper: String = "BA7816BF8F01CFEA414140DE5DAE2223\
                             B00361A396177A9CB410FF61F20015AD"
            .to_string();
        p.training_corpus_hash_hex = Box::leak(
            upper.into_boxed_str());
        assert!(is_permitted_for_production(&p));
    }

    #[test]
    fn mixed_case_hex_accepted() {
        let mut p = good_provenance();
        let mixed: String = "Ba7816Bf8f01CfEa414140dE5dae2223\
                             B00361a396177A9cb410ff61F20015aD"
            .to_string();
        p.trained_weights_hash_hex = Box::leak(
            mixed.into_boxed_str());
        assert!(is_permitted_for_production(&p));
    }

    #[test]
    fn first_non_hex_char_walks_in_order() {
        assert_eq!(first_non_hex_char("abcdef"), None);
        assert_eq!(first_non_hex_char("ABCDEF"), None);
        assert_eq!(first_non_hex_char("012345"), None);
        assert_eq!(first_non_hex_char("0aZ1"), Some('Z'));
        assert_eq!(first_non_hex_char("中文"), Some('中'));
    }

    #[test]
    fn tier_ordinal_round_trip() {
        for o in 0..=3 {
            let t = Tier::from_ordinal(o).unwrap();
            assert_eq!(t.ordinal(), o);
        }
        assert_eq!(Tier::from_ordinal(-1), None);
        assert_eq!(Tier::from_ordinal(4), None);
        assert_eq!(Tier::from_ordinal(99), None);
    }

    #[test]
    fn rejection_codes_distinct() {
        // All 8 codes (0..=7) must be reachable for the C ABI
        let mut codes = std::collections::HashSet::new();
        codes.insert(0);
        codes.insert(rejection_code(Some(
            &Rejection::MalformedHashLength {
                field: HashField::TrainingCorpus,
                length: 0 })));
        codes.insert(rejection_code(Some(
            &Rejection::MalformedHashLength {
                field: HashField::TrainedWeights,
                length: 0 })));
        codes.insert(rejection_code(Some(
            &Rejection::MalformedHashContent {
                field: HashField::TrainingCorpus,
                first_invalid_char: 'x' })));
        codes.insert(rejection_code(Some(
            &Rejection::MalformedHashContent {
                field: HashField::TrainedWeights,
                first_invalid_char: 'x' })));
        codes.insert(rejection_code(Some(
            &Rejection::BelowProductionTier {
                tier: Tier::PeerReviewed })));
        codes.insert(rejection_code(Some(
            &Rejection::NonProductionTierCarriesAttestation
        )));
        codes.insert(rejection_code(Some(
            &Rejection::MissingAttestationForProductionTier
        )));
        assert_eq!(codes.len(), 8);
    }
}
