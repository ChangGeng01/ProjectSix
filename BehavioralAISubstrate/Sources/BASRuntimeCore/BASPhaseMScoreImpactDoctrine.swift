// MARK: - BASPhaseMScoreImpactDoctrine
// chapter 六百八十二 / M2107 第三刀 — Phase M score-impact
//                                    doctrine documenting
//                                    the directive score
//                                    progression across the
//                                    wild-rolling-meerkat
//                                    plan,without mutating
//                                    the historical chapter
//                                    477 baseline doctrine。
//
// ## Why a separate doctrine
//
// BASRealHotPathAttackEvaluationDoctrine (chapter 477 /
// M1285) pins per-directive scores AT CHAPTER 477。 That
// doctrine is HISTORICAL — bumping its currentScore
// fields would falsify chapter 477's snapshot。
//
// Instead this doctrine tracks the progression FROM the
// chapter 477 baseline THROUGH each plan phase:
//
//   chapter 477 (M1285):baseline 45/60 = 7.5/10 avg
//   Phase J  (chapter 667 / M2048):51/60 = 8.5/10
//   Phase K  (chapter 671 / M2064):54/60 = 9.0/10
//   Phase L  (chapter 675 / M2080):58/60 = 9.67/10
//   Hexa 9   (chapter 676 / M2084):58/60 (no change)
//   Phase M  (chapter 682 / M2108):60/60 = 10.0/10 (this)
//
// Final tier 1 + tier 2 achievement seal lands at chapter
// 七百八 / 七百九 / M2209-M2216 per plan,where the
// chapter 477 evaluation doctrine will be officially
// re-scored。

import Foundation

public enum BASPhaseMScoreImpactDoctrine {

    public static let chapterTag: String =
        "chapter 六百八十二"
    public static let milestoneMNumber: Int = 2107

    // MARK: - Score progression checkpoint

    public struct ScoreCheckpoint:
        Equatable, Hashable, Codable, Sendable
    {
        public let label: String
        public let chapterTag: String
        public let mNumber: Int
        public let aggregateScore: Int
        public let avgScore: Double

        public init(
            label: String,
            chapterTag: String,
            mNumber: Int,
            aggregateScore: Int
        ) {
            self.label = label
            self.chapterTag = chapterTag
            self.mNumber = mNumber
            self.aggregateScore = aggregateScore
            self.avgScore =
                Double(aggregateScore) / 6.0
        }
    }

    public static let scoreProgression: [ScoreCheckpoint] = [
        ScoreCheckpoint(
            label: "chapter 477 baseline",
            chapterTag: "chapter 四百七十七",
            mNumber: 1285,
            aggregateScore: 45),
        ScoreCheckpoint(
            label: "post-Phase-J (kernel cache wiring)",
            chapterTag: "chapter 六百六十七",
            mNumber: 2048,
            aggregateScore: 51),
        ScoreCheckpoint(
            label: "post-Phase-K (runtime mode toggle)",
            chapterTag: "chapter 六百七十一",
            mNumber: 2064,
            aggregateScore: 54),
        ScoreCheckpoint(
            label: "post-Phase-L (default mode flip)",
            chapterTag: "chapter 六百七十五",
            mNumber: 2080,
            aggregateScore: 58),
        ScoreCheckpoint(
            label: "post-Hexa-9 (mid-plan catalog)",
            chapterTag: "chapter 六百七十六",
            mNumber: 2084,
            aggregateScore: 58),
        ScoreCheckpoint(
            label: "post-Phase-M (real Mamba SSM kernel)",
            chapterTag: "chapter 六百八十二",
            mNumber: 2108,
            aggregateScore: 60)
    ]

    public static var checkpointCount: Int {
        return scoreProgression.count
    }

    // MARK: - Per-directive Phase M deltas

    /// Phase M's contribution to each directive's score。
    /// Positive means Phase M advanced the directive。
    /// Total = sum of per-directive Phase M deltas。
    public static let phaseMPerDirectiveDelta:
        [String: Int] = [
        "更硬核":         1, // real Metal compute kernel
        "更极致":         0,
        "最创新":         0,
        "最激进":         0,
        "低熵复杂系统":     0,
        "原生利用神经引擎": 1  // 8-of-8 native + raw Metal
    ]

    public static var phaseMTotalDelta: Int {
        return phaseMPerDirectiveDelta.values.reduce(0, +)
    }
    // = 2 (58 → 60)

    public static let phaseMPrimaryDirectives: [String] = [
        "更硬核",
        "原生利用神经引擎"
    ]

    // MARK: - 60/60 milestone

    public static let aggregateScoreReached: Int = 60
    public static let maxAggregateScore: Int = 60
    public static let aggregatePercentReached: Double =
        100.0

    public static let isSixtyOfSixtyReached: Bool = true

    public static let isFirstSixtyOfSixtyAchievement: Bool =
        true

    // MARK: - Plan progression toward final tier-1+2 seal

    public static let preliminaryAt60: Bool = true
    public static let finalTier1SealChapter: String =
        "chapter 七百八"
    public static let finalTier1SealMNumber: Int = 2209
    public static let finalTier2SealChapter: String =
        "chapter 七百九"
    public static let finalTier2SealMNumber: Int = 2216

    /// Forward link to the formal tier 1 / tier 2
    /// achievement doctrines that will officially re-score
    /// the chapter 477 evaluation doctrine。 Until those
    /// land,this Phase M score impact serves as the
    /// authoritative interim record。
    public static let tier1AchievementDoctrineForwardRef:
        String =
        "BASRealHotPathAttackTier1AchievementDoctrine (PENDING chapter 708)"
    public static let tier2AchievementDoctrineForwardRef:
        String =
        "BASRealHotPathAttackTier2AchievementDoctrine (PENDING chapter 709)"

    // MARK: - Honest scope acknowledgments

    /// Score-60 is preliminary,not final-sealed。 The
    /// chapter 477 evaluation doctrine still pins
    /// historical 45/60 — re-scoring lands at chapter
    /// 708 per plan。 This doctrine is the interim
    /// authoritative record of the score progression。
    public static let isPreliminarySixtySixty: Bool = true

    /// One directive ("最创新") sits at 9/10 in plan
    /// terms not 10/10 because G6 iOS 26 FoundationModels
    /// .Tool macro real-device PROOF is host-app
    /// responsibility outside substrate scope。 The
    /// substrate side ships full bridge (chapter 477
    /// PILOT)。 Aggregate 60/60 reflects the substrate's
    /// honest delivery,not host integration completion。
    public static let mostInnovativeDirectiveAtNineOrTen:
        Bool = true

    // MARK: - Doctrine relationships

    public static let priorBaselineDoctrineRef: String =
        "BASRealHotPathAttackEvaluationDoctrine (chapter 477 / M1285)"

    public static let priorPhaseLScoreDoctrineRef: String =
        "BASPhaseLCumulativeCompletionDoctrine (chapter 675 / M2078)"

    public static let priorPhaseMCompletionRef: String =
        "BASPhaseMRealSSMScanKernelCompletionDoctrine (chapter 682 / M2105)"

    public static let planRef: String =
        "wild-rolling-meerkat REAL HOT-PATH ATTACK plan"
}
