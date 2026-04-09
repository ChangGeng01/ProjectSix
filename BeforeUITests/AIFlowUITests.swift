import XCTest

@MainActor
final class AIFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 12

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testQuickFlowShowsStubRefinement() throws {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["home.mode.quick"].waitForExistence(timeout: timeout))
        app.buttons["home.mode.quick"].tap()

        tap(app.buttons["quick.motivation.stressed"])
        tap(app.buttons["quick.outcome.regret"])
        tap(app.buttons["quick.control.maybe"])
        tap(app.buttons["quick.evaluate"])

        let current = app.staticTexts["quick.result.current"]
        XCTAssertTrue(current.waitForExistence(timeout: timeout))
        waitForLabel(containing: "Stub current:", on: current)

        let after = app.staticTexts["quick.result.after"]
        XCTAssertTrue(after.waitForExistence(timeout: timeout))
        waitForLabel(containing: "Stub after:", on: after)
    }

    func testBalanceFlowShowsStubBoard() throws {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["home.mode.balance"].waitForExistence(timeout: timeout))
        app.buttons["home.mode.balance"].tap()

        enterText("Should I take this side project?", into: inputElement("balance.prompt.input", app: app))
        enterText("I want extra momentum.", into: inputElement("balance.desire.input", app: app))
        enterText("I might burn out.", into: inputElement("balance.concern.input", app: app))
        tap(app.buttons["balance.evaluate"])

        let headline = app.staticTexts["balance.result.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: timeout))
        waitForLabel(
            containingAny: [
                "Stub balance board",
                "This looks like a trade-off"
            ],
            on: headline
        )

        let focus = app.staticTexts["balance.result.focusTitle"]
        XCTAssertTrue(reveal(focus, in: app))
        waitForLabel(
            containingAny: [
                "Stub priority",
                "Name what you are protecting"
            ],
            on: focus
        )
    }

    func testMirrorFlowShowsStubMirror() throws {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["home.mode.mirror"].waitForExistence(timeout: timeout))
        app.buttons["home.mode.mirror"].tap()

        enterText("Should I stay in this relationship?", into: inputElement("mirror.prompt.input", app: app))
        enterText("I feel exhausted and sad.", into: inputElement("mirror.emotion.input", app: app))
        enterText("The same conflict keeps repeating.", into: inputElement("mirror.relationship.input", app: app))
        enterText("Moving out would be expensive.", into: inputElement("mirror.reality.input", app: app))
        tap(app.buttons["mirror.evaluate"])

        let headline = app.staticTexts["mirror.result.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: timeout))
        waitForLabel(
            containingAny: [
                "Stub mirror",
                "Repetition is part of the signal."
            ],
            on: headline
        )

        let tension = app.staticTexts["mirror.result.tension"]
        XCTAssertTrue(tension.waitForExistence(timeout: timeout))
        waitForLabel(
            containingAny: [
                "Stub tension:",
                "A single painful moment hurts."
            ],
            on: tension
        )
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment.merge(
            [
                "BEFORE_TEST_INTELLIGENCE_MODE": "assistive",
                "BEFORE_TEST_MODEL_PROVIDER": "gemmaE4B",
                "BEFORE_TEST_ALLOW_FALLBACKS": "1",
                "BEFORE_TEST_MODEL_STUB_PROFILE": "smoke",
                "BEFORE_TEST_SKIP_ONBOARDING": "1",
                "BEFORE_TEST_CLEAN_LAUNCH": "1"
            ],
            uniquingKeysWith: { _, new in new }
        )
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        element.tap()
    }

    private func inputElement(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.textFields[identifier],
            app.textViews[identifier],
            app.descendants(matching: .any)[identifier]
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: timeout) {
            return candidate
        }

        return app.descendants(matching: .any)[identifier]
    }

    private func enterText(
        _ text: String,
        into element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        element.tap()
        element.typeText(text)
    }

    private func waitForLabel(containing text: String, on element: XCUIElement) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    private func waitForLabel(containingAny texts: [String], on element: XCUIElement) {
        let predicates = texts.map { NSPredicate(format: "label CONTAINS %@", $0) }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        let scrollContainers = [
            app.scrollViews.firstMatch,
            app.tables.firstMatch,
            app.collectionViews.firstMatch
        ]

        for _ in 0..<maxSwipes {
            if element.exists {
                return true
            }

            if let container = scrollContainers.first(where: { $0.exists && !$0.frame.isEmpty }) {
                container.swipeUp()
            } else {
                app.swipeUp()
            }
        }

        return element.waitForExistence(timeout: 1)
    }
}
