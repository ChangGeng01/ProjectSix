import XCTest
@testable import BASSovereign

final class BASSovereignHostVersionTreeTests: XCTestCase {

    // MARK: - Registration invariants

    func testGenesisAcceptsOnlyOnce() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        do {
            try await tree.registerGenesis(versionID: "v0")
            XCTFail("expected duplicate")
        } catch BASSovereignHostVersionTree.TreeError
            .duplicateVersion(let id)
        {
            XCTAssertEqual(id, "v0")
        }
    }

    func testRegisterVersionRequiresKnownParent() async throws {
        let tree = BASSovereignHostVersionTree()
        do {
            try await tree.registerVersion(
                versionID: "v1",
                parentID: "missing-parent",
                diffSummary: "x")
            XCTFail("expected parent-unknown")
        } catch BASSovereignHostVersionTree.TreeError
            .parentUnknown(let parent, let child)
        {
            XCTAssertEqual(parent, "missing-parent")
            XCTAssertEqual(child, "v1")
        }
    }

    func testSelfParentIsRejected() async throws {
        let tree = BASSovereignHostVersionTree()
        do {
            try await tree.registerVersion(
                versionID: "v-self",
                parentID: "v-self",
                diffSummary: "x")
            XCTFail("expected self-reference")
        } catch BASSovereignHostVersionTree.TreeError
            .parentSelfReference(let id)
        {
            XCTAssertEqual(id, "v-self")
        }
    }

    // MARK: - Ancestors / descendants

    func testAncestorsClimbToRoot() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "a")
        try await tree.registerVersion(
            versionID: "v2", parentID: "v1", diffSummary: "b")
        try await tree.registerVersion(
            versionID: "v3", parentID: "v2", diffSummary: "c")

        let ancestors = try await tree.ancestors(of: "v3")
        XCTAssertEqual(ancestors.map(\.versionID), ["v2", "v1", "v0"])
    }

    func testDescendantsWalkTheTree() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "a")
        try await tree.registerVersion(
            versionID: "v2", parentID: "v0", diffSummary: "b")
        try await tree.registerVersion(
            versionID: "v3", parentID: "v1", diffSummary: "c")

        let desc = try await tree.descendants(of: "v0")
        let ids = Set(desc.map(\.versionID))
        XCTAssertEqual(ids, ["v1", "v2", "v3"])
    }

    // MARK: - Lineage (diff path)

    func testLineageBetweenTwoBranches() async throws {
        //       v0
        //      /  \
        //    v1    v2
        //    |
        //    v3
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "a")
        try await tree.registerVersion(
            versionID: "v2", parentID: "v0", diffSummary: "b")
        try await tree.registerVersion(
            versionID: "v3", parentID: "v1", diffSummary: "c")

        let path = try await tree.lineage(from: "v3", to: "v2")
        XCTAssertEqual(path.commonAncestor, "v0")
        XCTAssertEqual(path.up, ["v3", "v1"])
        XCTAssertEqual(path.down, ["v2"])
    }

    func testLineageDegenerateSameNode() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        let path = try await tree.lineage(from: "v0", to: "v0")
        XCTAssertEqual(path.commonAncestor, "v0")
        XCTAssertEqual(path.up, [])
        XCTAssertEqual(path.down, [])
    }

    // MARK: - Rollback target selection

    func testLatestKnownGoodSkipsBadNodes() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.registerVersion(
            versionID: "v1", parentID: "v0", diffSummary: "a")
        try await tree.registerVersion(
            versionID: "v2", parentID: "v1", diffSummary: "b")
        try await tree.markBad(versionID: "v2", reason: "tainted")
        try await tree.markBad(versionID: "v1", reason: "tainted")

        let good = try await tree.latestKnownGoodAncestor(of: "v2")
        XCTAssertEqual(good?.versionID, "v0")
    }

    func testNoKnownGoodAncestorReturnsNil() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.markBad(versionID: "v0", reason: "tainted")
        let good = try await tree.latestKnownGoodAncestor(of: "v0")
        XCTAssertNil(good)
    }

    // MARK: - Mark back to good

    func testMarkGoodReverts() async throws {
        let tree = BASSovereignHostVersionTree()
        try await tree.registerGenesis(versionID: "v0")
        try await tree.markBad(versionID: "v0", reason: "tainted")
        try await tree.markGood(versionID: "v0")
        let n = await tree.node("v0")!
        XCTAssertTrue(n.isKnownGood)
        XCTAssertNil(n.badReason)
    }
}
