// MARK: - BASChapterDoctrineRegistry — chapter 四百六十四+ /  M1232+
//                                       chapter 七百二 native-port
//
// chapter 七百二 native-port — DATA PORT。 The original
// 25,131-line Swift literal block (Phase 2+ chapters
// 464-...) was JSON-encoded once via __OneShotJSONDumper
// and committed as Resources/chapter_doctrine_full_
// registry.json。 This file is now a ~120-LOC loader。
// Net Swift LOC drop: ~25,000。
//
// ## Why this is safe
//
// `BASRegistryFrozenHashTests.testFullRegistryHasStable
//  Hash` asserts the SHA256 of
//      JSONEncoder().encode(.all)  with .sortedKeys
// equals a frozen hex string。 The pre-port behaviour
// was:
//      .all = AllLiterals.all + phase2RegistryNative
//             Chapters
// Where `phase2RegistryNativeChapters` was a 25,000+
// LOC Swift literal block。 We've persisted the
// CONCATENATED result of that addition (literals +
// phase2) as one JSON file。 The loader returns the
// decoded array directly,so byte-identical JSON →
// byte-identical SHA256 → frozen-hash test passes。
//
// ## Legacy literal block — preserved per 全comment 不要删除
//
// The original 25k-LOC `phase2RegistryNativeChapters`
// array literal is NOT in this file anymore — its
// content is byte-equivalent in the committed JSON
// resource。 To recover the literals,JSONDecode the
// resource → all 600+ `BASChapterDoctrineRecord`
// instances each carrying the exact same data the
// legacy Swift literals carried。
//
// ## Original chapter 466 commentary (preserved for
//    archaeological context)
//
// All-in-one chapter doctrine registry consolidating
// Phase 3 literal extraction (chapters 403-463) + Phase
// 2+ registry-native chapters (464+)。

import Foundation

public enum BASChapterDoctrineRegistry {

    /// chapter 七百二 native-port — all chapter records
    /// decoded from the committed JSON resource。 The
    /// resource was generated as the byte-identical
    /// pre-port concatenation:
    ///     AllLiterals.all + phase2RegistryNativeChapters
    /// so `.all` returns the same ordered array the
    /// pre-port `static let all` returned。
    public static let all: [BASChapterDoctrineRecord] =
        loadFromJSONResource()

    /// chapter 七百二 native-port — JSON loader。 Fails
    /// fatal on missing/corrupted resource — same rationale
    /// as BASChapterDoctrineRegistry+AllLiterals。
    private static func loadFromJSONResource()
        -> [BASChapterDoctrineRecord]
    {
        guard let url = Bundle.module.url(
            forResource:
                "chapter_doctrine_full_registry",
            withExtension: "json")
        else {
            fatalError(
                "chapter 七百二 native-port:" +
                " chapter_doctrine_full_registry.json" +
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
                " chapter_doctrine_full_registry.json:" +
                " \(error)")
        }
    }

    /// Lookup by exact chapter tag string。 Returns
    /// nil if no entry exists。
    public static func recordFor(
        chapterTag: String
    ) -> BASChapterDoctrineRecord? {
        return all.first { $0.chapterTag == chapterTag }
    }

    /// Lookup by the chapter's first M-number。
    public static func recordFor(
        mNumberFirst: Int
    ) -> BASChapterDoctrineRecord? {
        return all.first {
            $0.mNumberFirst == mNumberFirst
        }
    }

    /// Count of currently registered chapters。
    public static var count: Int { all.count }
}
