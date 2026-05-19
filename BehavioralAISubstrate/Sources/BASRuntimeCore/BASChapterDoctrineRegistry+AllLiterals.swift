// MARK: - BASChapterDoctrineRegistry+AllLiterals — chapter 四百六十六 / M1241
// 系统熵 reduction
//
// chapter 七百二 native-port — DATA PORT。 The original
// 3,902-line Swift literal block was JSON-encoded once
// via `__OneShotJSONDumper` and committed as
// `Resources/chapter_doctrine_all_literals.json`。 This
// file is now a ~80-LOC loader that decodes the JSON at
// first access。 Net Swift LOC drop: ~3,800。
//
// ## Why this is safe
//
// `BASRegistryFrozenHashTests.testRegistryLiteralsHave
// StableHash` asserts the SHA256 of
//     `JSONEncoder().encode(BASChapterDoctrineRegistry
//      AllLiterals.all)` with `.sortedKeys` outputFormatting
// equals a frozen hex string。 The Codable round-trip
// (Swift struct → JSON → struct → JSON) is byte-stable
// IFF the JSON was emitted with sortedKeys (which the
// dumper did) — re-encoding decoded structs with the
// same options yields byte-identical output。 No frozen
// hash change → test stays green。
//
// ## Legacy literal block — preserved per 全comment 不要删除
//
// The original 3,902-line `static let chapter403 …
// chapter463 + static let all = [...]` block is NOT in
// this file anymore — its content is byte-equivalent in
// the committed JSON resource。 To recover the literals
// run the one-shot dumper in reverse:JSONDecode the
// resource → 61 `BASChapterDoctrineRecord` instances
// each carrying the exact same data the legacy Swift
// literals carried。
//
// ## Original chapter 466 commentary (preserved for
//    archaeological context)
//
// **STRUCTURAL DEBT REPAYMENT chapter 4** — Phase 3
// of doctrine collapse。 Ships LITERAL records for
// all 61 chapters (403-463),AUTO-EXTRACTED from
// the corresponding BASChapter###EntropyDoctrine.swift
// source files via /tmp/extract_doctrines.py (committed
// to git history for reproducibility but the generated
// file below is the canonical source going forward)。
// chapter 七百二 deepens that move: the AUTO-EXTRACTED
// Swift literals are themselves auto-converted to JSON。

import Foundation

public enum BASChapterDoctrineRegistryAllLiterals {

    /// chapter 七百二 native-port — 61 chapter records
    /// decoded from the committed JSON resource。
    /// Cached via lazy static let so the decode runs
    /// exactly once per process lifetime。
    public static let all: [BASChapterDoctrineRecord] =
        loadFromJSONResource()

    /// chapter 七百二 native-port — JSON loader。 Fails
    /// fatal if the resource is missing or malformed:
    /// the registry surface is foundational (consumed
    /// by ~30 substrate sites) and a missing/corrupted
    /// resource is a build-pipeline bug, not a runtime
    /// recoverable error。
    private static func loadFromJSONResource()
        -> [BASChapterDoctrineRecord]
    {
        guard let url = Bundle.module.url(
            forResource: "chapter_doctrine_all_literals",
            withExtension: "json")
        else {
            fatalError(
                "chapter 七百二 native-port:" +
                " chapter_doctrine_all_literals.json" +
                " missing from BASRuntimeCore Resources")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(
                [BASChapterDoctrineRecord].self,
                from: data)
            return decoded
        } catch {
            fatalError(
                "chapter 七百二 native-port:" +
                " failed to decode" +
                " chapter_doctrine_all_literals.json:" +
                " \(error)")
        }
    }
}
