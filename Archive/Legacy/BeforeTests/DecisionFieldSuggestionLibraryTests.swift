import XCTest
@testable import Before

final class DecisionFieldSuggestionLibraryTests: XCTestCase {
    func testBalanceFieldsExposeThreeSuggestionsEach() {
        for field in BalanceField.allCases {
            let suggestions = DecisionFieldSuggestionLibrary.suggestions(for: field)
            XCTAssertEqual(suggestions.count, 3)
            XCTAssertEqual(Set(suggestions).count, suggestions.count)
            XCTAssertTrue(suggestions.allSatisfy { !$0.isEmpty })
        }
    }

    func testMirrorFieldsExposeThreeSuggestionsEach() {
        for field in MirrorField.allCases {
            let suggestions = DecisionFieldSuggestionLibrary.suggestions(for: field)
            XCTAssertEqual(suggestions.count, 3)
            XCTAssertEqual(Set(suggestions).count, suggestions.count)
            XCTAssertTrue(suggestions.allSatisfy { !$0.isEmpty })
        }
    }
}
