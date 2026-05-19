// SPDX:internal
//
// enums.rs — chapter 七百三 第四刀 / M2174
//
// Typed permit / scope / decision enums。 Raw values pinned for
// wire stability (chapter 八十七)。

use serde::{Deserialize, Serialize};

/// Permit mode — who is currently authorized to act on behalf
/// of the host。 Mirrors Swift's BASPermitMode raw-stable enum。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PermitMode {
    Default,
    Elevated,
    Sovereign,
    HostInitiated,
    Guard,
    Quarantine,
}

/// Memory / capability scope — which slice of the world the
/// caller is allowed to touch。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Scope {
    User,
    Session,
    Turn,
    Global,
    External,
}

/// Verdict outcomes from the L14 sovereign verdict engine。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Verdict {
    Allow,
    AllowWithGuard,
    Defer,
    Refuse,
    Quarantine,
    FailClosed,
}

/// Risk climate buckets。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RiskClimate {
    Calm,
    Watchful,
    Elevated,
    Crisis,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn permit_mode_round_trip() {
        for mode in [
            PermitMode::Default, PermitMode::Elevated,
            PermitMode::Sovereign, PermitMode::HostInitiated,
            PermitMode::Guard, PermitMode::Quarantine,
        ] {
            let j = serde_json::to_string(&mode).unwrap();
            let back: PermitMode =
                serde_json::from_str(&j).unwrap();
            assert_eq!(mode, back);
        }
    }

    #[test]
    fn scope_round_trip() {
        for s in [
            Scope::User, Scope::Session, Scope::Turn,
            Scope::Global, Scope::External,
        ] {
            let j = serde_json::to_string(&s).unwrap();
            let back: Scope =
                serde_json::from_str(&j).unwrap();
            assert_eq!(s, back);
        }
    }

    #[test]
    fn verdict_round_trip() {
        for v in [
            Verdict::Allow, Verdict::AllowWithGuard,
            Verdict::Defer, Verdict::Refuse,
            Verdict::Quarantine, Verdict::FailClosed,
        ] {
            let j = serde_json::to_string(&v).unwrap();
            let back: Verdict =
                serde_json::from_str(&j).unwrap();
            assert_eq!(v, back);
        }
    }

    #[test]
    fn risk_climate_raw_values_pinned() {
        let cases = [
            (RiskClimate::Calm, "\"calm\""),
            (RiskClimate::Watchful, "\"watchful\""),
            (RiskClimate::Elevated, "\"elevated\""),
            (RiskClimate::Crisis, "\"crisis\""),
        ];
        for (v, expected) in cases {
            let j = serde_json::to_string(&v).unwrap();
            assert_eq!(j, expected);
        }
    }
}
