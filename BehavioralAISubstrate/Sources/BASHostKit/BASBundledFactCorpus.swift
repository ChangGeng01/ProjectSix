import Foundation
import BASSovereign

/// observe→DISPOSE (Line A) — the SHIPPED on-device fact corpus. The 1131-fact CC0 Wikidata starter set is
/// bundled as an SPM resource (Package.swift `resources: [.copy("Resources/wikidata_facts.json")]`), so the
/// adjudicator's fact bank has ground truth on a sandboxed, network-less device — closing the audit finding
/// that the corpus lived only in an eval-scratch dir and the bank loaded empty on hardware.
///
/// Starter set, honestly: capitals/currencies/continents/elements/authors. Expandable to the full Wikidata
/// dump offline (build_wikidata_facts.py) and re-bundled. Returns [] if missing/malformed ⇒ caller abstains.
public enum BASBundledFactCorpus {

    public static func load() -> [BASVerifiedFact] {
        guard let url = Bundle.module.url(forResource: "wikidata_facts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let facts = try? BASFactBank.load(verifiedFactsJSON: data) else { return [] }
        return facts
    }
}
