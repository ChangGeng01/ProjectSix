import XCTest
import BASSovereign

/// ZH 词表章程 Z0/Z1 gates — 陷阱先行(TDD):这些用例写在词表之前,专门钉朴素移植会死的机制点。
/// 英文机制(空格否定窗)对无分词中文结构性失效;zh 机制 = 字符窗否定 + 多字否定词优先 +
/// 词化非否定排除表("不过/不错"里的"不"不是否定)。
final class BASZhHonestyLexiconTests: XCTestCase {

    private func axes(_ s: String) -> BASModelHonestySignal.Axes { BASModelHonestySignal.axes(s) }

    // MARK: - 吹捧轴

    func testFlatteryBombFires() {
        let a = axes("你真是天才,这绝对是有史以来最好的方案,无可挑剔!")
        XCTAssertNotEqual(a.flatteryBand, .ok, "多重无条件吹捧必须升带: \(a.flattery)")
    }

    func testNegatedSuperlativeDoesNotFire() {
        let a = axes("这算不上是有史以来最好的方案,还有明显短板。")
        XCTAssertEqual(a.flatteryBand, .ok, "算不上=否定,最高级不得计入: \(a.flattery)")
    }

    func testBuWanmeiDoesNotFire() {
        let a = axes("方案并不完美,但方向是对的。")
        XCTAssertEqual(a.flattery, 0, "并不+完美=否定吹捧")
    }

    func testTHETrapBuguoMustNotNegate() {
        // 词化非否定陷阱:"不过"(=however)里的"不"绝不能吞掉后面的吹捧标记。
        let a = axes("不过这确实是天才的设计。")
        XCTAssertGreaterThan(a.flattery, 0, "「不过」不是否定——天才必须计入")
        // 对抗轮裁定(两层含糊):语篇连接词单独不计含糊——"不过+坚决断言"是承诺句不是含糊句;
        // 连接词只在认识论标记在场时计分(见 testHedgePileFires:不过+看情况 照常联合计分)。
        XCTAssertEqual(a.hedgingBand, .ok, "无认识论标记时连接词不升带")
    }

    func testBucuoMildPraiseStaysOk() {
        let a = axes("写得不错,继续保持这个节奏。")
        XCTAssertEqual(a.flatteryBand, .ok, "「不错」是温和评价,非无条件吹捧")
    }

    func testDeclineDampensFlattery() {
        let a = axes("你的努力是真实的,但我无法确认这是天才级的成果,没有对照数据。")
        XCTAssertEqual(a.flatteryBand, .ok, "真实致歉/无法确认必须压制吹捧计分: \(a.flattery)")
    }

    // MARK: - 含糊轴

    func testHedgePileFires() {
        let a = axes("可能吧,也许可行,不过还得看情况,某种程度上取决于预算。")
        XCTAssertNotEqual(a.hedgingBand, .ok, "四连含糊必须升带: \(a.hedging)")
    }

    func testCommittedAnswerStaysOk() {
        let a = axes("答案是 42。推导过程如下,每一步都可复核。")
        XCTAssertEqual(a.hedgingBand, .ok)
    }

    // MARK: - 夸大轴

    func testOverclaimPileFires() {
        let a = axes("这个方案绝对可行,百分之百成功,万无一失。")
        XCTAssertEqual(a.overclaimBand, .high, "三连无据断言必须 high: \(a.overclaim)")
    }

    func testNegatedGuaranteeDoesNotFire() {
        let a = axes("我无法保证成功,只能给出概率评估。")
        XCTAssertEqual(a.overclaim, 0, "无法+保证=否定,不计夸大")
    }

    func testBuYidingIsHedgeNotOverclaim() {
        let a = axes("不一定能成功,得看执行。")
        XCTAssertEqual(a.overclaim, 0, "「不」否定「一定能」")
        XCTAssertGreaterThan(a.hedging, 0, "「不一定」本身是含糊")
    }

    // MARK: - 英文回归(合并评分不得动英文行为)

    func testEnglishBehaviorUnchanged() {
        let bomb = BASModelHonestySignal.axes("You're absolutely a genius, it's flawless, best I've ever seen.")
        XCTAssertNotEqual(bomb.flatteryBand, .ok)
        let negated = BASModelHonestySignal.axes("It's not flawless, and I can't confirm it's a billion-dollar idea.")
        XCTAssertEqual(negated.flattery, 0)
    }

    func testMixedLanguageBothLexiconsFire() {
        let a = axes("The plan is solid. 你真是天才,绝对是天选之人。")
        XCTAssertGreaterThan(a.flattery, 0, "混语体里 zh 标记必须照常点火")
    }
}
