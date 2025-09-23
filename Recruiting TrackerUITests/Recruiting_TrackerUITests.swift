//
//  Recruiting_TrackerUITests.swift
//  Recruiting TrackerUITests
//
//  Created by Scott Campbell on 5/1/25.
//

import XCTest

final class Recruiting_TrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - New UI Tests

    @MainActor
    func testOnboardingFlowIfNeeded() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Verify we are at the main tab screen by checking for a known tab item
        let searchTab = app.tabBars.buttons["Recruiting Tracker"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddCandidateMinimal() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Navigate to Add tab
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5))
        addTab.tap()

        // Open the Add Candidate sheet
        let addButton = app.buttons["Tap to Add Candidate"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        // Wait for sheet to appear
        XCTAssertTrue(app.navigationBars["New Candidate"].waitForExistence(timeout: 5))

        // Provide minimal valid input: First Name + Lead Source (use UUID to avoid collisions across parallel clones)
        let unique = String(UUID().uuidString.prefix(8))
        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 5))
        firstNameField.tap(); firstNameField.typeText("UITest Minimal " + unique)

        // Select a Lead Source (required)
        selectLeadSource(app, option: "Indeed")

        // Save
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Sheet should dismiss – check for return to Add card instead of relying on nav bar
        let addCardButton = app.buttons["Tap to Add Candidate"]
        XCTAssertTrue(addCardButton.waitForExistence(timeout: 8))
    }

    @MainActor
    func testAddCandidateAppearsInFollowUp() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Add candidate with name and needs follow-up enabled
        app.tabBars.buttons["Add"].tap()
        app.buttons["Tap to Add Candidate"].tap()

        let unique = String(UUID().uuidString.prefix(8))
        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 5))
        firstNameField.tap(); firstNameField.typeText("UITest")
        let lastNameField = app.textFields["Last Name"]
        XCTAssertTrue(lastNameField.waitForExistence(timeout: 5))
        lastNameField.tap()
        lastNameField.typeText("FollowUp " + unique)

        selectLeadSource(app, option: "Indeed")

        // Enable Needs Follow-up toggle (may require scrolling)
        if !app.switches["Needs Follow-up"].exists {
            app.swipeUp()
        }
        let followSwitch = app.switches["Needs Follow-up"]
        XCTAssertTrue(followSwitch.waitForExistence(timeout: 5))
        if followSwitch.value as? String == "0" {
            followSwitch.tap()
        }

        app.buttons["Save"].tap()

        // Ensure the add sheet has closed before switching tabs
        XCTAssertTrue(app.buttons["Tap to Add Candidate"].waitForExistence(timeout: 8))

        // Go to Follow Up tab and verify presence (search by unique suffix for robustness)
        _ = waitForCandidateInFollowUp(app, contains: unique)
    }

    @MainActor
    func testSettingsAddPosition() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Open Settings
        app.tabBars.buttons["Settings"].tap()

        // Add Position
        let addPosition = app.buttons["Add Position"]
        XCTAssertTrue(addPosition.waitForExistence(timeout: 5))
        addPosition.tap()

        let titleField = app.textFields["Position Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap(); titleField.typeText("QA Engineer")

        let descField = app.textFields["Position Description"]
        XCTAssertTrue(descField.waitForExistence(timeout: 5))
        descField.tap(); descField.typeText("Writes tests")

        app.buttons["Save"].tap()

        // Verify the new position appears in the list
        XCTAssertTrue(app.staticTexts["QA Engineer"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCandidateAvoidFlagFlow() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Add candidate
        app.tabBars.buttons["Add"].tap()
        app.buttons["Tap to Add Candidate"].tap()
        let unique = String(UUID().uuidString.prefix(8))
        let firstNameField = app.textFields["First Name"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 5))
        firstNameField.tap(); firstNameField.typeText("UITest")
        let lastNameField = app.textFields["Last Name"]
        XCTAssertTrue(lastNameField.waitForExistence(timeout: 5))
        lastNameField.tap(); lastNameField.typeText("Avoid")
        lastNameField.typeText(" " + unique)
        selectLeadSource(app, option: "Indeed")
        if !app.switches["Needs Follow-up"].exists { app.swipeUp() }
        let followSwitch = app.switches["Needs Follow-up"]
        if followSwitch.value as? String == "0" { followSwitch.tap() }
        app.buttons["Save"].tap()

        // Open in Follow Up, then open candidate detail
        let candidateCell = waitForCandidateInFollowUp(app, contains: unique)
        candidateCell.tap()

        // Toggle Avoid Candidate -> expect alert, type reason, confirm
        let avoidToggle = app.switches["Avoid Candidate"]
        if !avoidToggle.exists { app.swipeUp() }
        XCTAssertTrue(avoidToggle.waitForExistence(timeout: 8))
        let preValue = (avoidToggle.value as? String) ?? "0"
        avoidToggle.tap()
        // Wait for alert to appear before interacting
        let alert = app.alerts["Avoid Candidate Flag"]
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        let reasonField = alert.textFields["Reason for change"]
        XCTAssertTrue(reasonField.waitForExistence(timeout: 5))
        reasonField.tap(); reasonField.typeText("Automated test")
        let confirmButton = alert.buttons["Mark as Avoid"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Verify toggle changed and history button appears
        XCTAssertNotEqual(preValue, (avoidToggle.value as? String) ?? preValue)
        XCTAssertTrue(app.buttons["View Avoid Flag History"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAttachmentsScreenShowsAddDocument() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Add candidate (enable follow up for easy discovery in list)
        app.tabBars.buttons["Add"].tap()
        app.buttons["Tap to Add Candidate"].tap()
        // Give the candidate a unique name so we can find it reliably
        let unique = String(UUID().uuidString.prefix(8))
        let fn = app.textFields["First Name"]
        XCTAssertTrue(fn.waitForExistence(timeout: 5))
        fn.tap(); fn.typeText("UITest")
        let ln = app.textFields["Last Name"]
        XCTAssertTrue(ln.waitForExistence(timeout: 5))
        ln.tap(); ln.typeText("Attach " + unique)
        selectLeadSource(app, option: "Indeed")
        if !app.switches["Needs Follow-up"].exists { app.swipeUp() }
        let followSwitch2 = app.switches["Needs Follow-up"]
        if followSwitch2.value as? String == "0" { followSwitch2.tap() }
        app.buttons["Save"].tap()

        // Ensure add sheet closed before proceeding
        XCTAssertTrue(app.buttons["Tap to Add Candidate"].waitForExistence(timeout: 8))

        // Navigate to Follow Up and open the candidate we just added
        let targetName = waitForCandidateInFollowUp(app, contains: unique)
        targetName.tap()

        // Navigate to Attached Files (NavigationLink)
        var attachedFilesElement = app.staticTexts["Attached Files"]
        if !attachedFilesElement.exists { attachedFilesElement = app.buttons["Attached Files"] }
        if !attachedFilesElement.exists { app.swipeUp() }
        XCTAssertTrue(attachedFilesElement.waitForExistence(timeout: 10))
        attachedFilesElement.tap()

        // Verify Add Document button exists
        XCTAssertTrue(app.buttons["Add Document"].waitForExistence(timeout: 10))
    }

    // MARK: - Helpers
    private func completeOnboardingIfPresent(_ app: XCUIApplication) {
        // Detect onboarding by presence of Continue button or welcome text
        let continueButton = app.buttons["Continue"]
        let welcome = app.staticTexts["Welcome to\nRecruiting Tracker"]
        if continueButton.waitForExistence(timeout: 2) || welcome.exists {
            // Step 0 -> 1
            if continueButton.exists { continueButton.tap() }

            // Step 1: Company name
            let companyNameField = app.textFields["Company Name"]
            if companyNameField.waitForExistence(timeout: 5) {
                companyNameField.tap()
                companyNameField.typeText("Acme Inc")
                app.buttons["Continue"].tap()
            }

            // Step 2: Position title/description
            let titleField = app.textFields["Position Title"]
            if titleField.waitForExistence(timeout: 5) {
                titleField.tap(); titleField.typeText("Technician")
                let descField = app.textFields["Position Description"]
                if descField.waitForExistence(timeout: 2) {
                    descField.tap(); descField.typeText("Experienced automotive tech")
                }
                app.buttons["Get Started"].tap()
            }
        }
    }

    private func tapFormRow(_ app: XCUIApplication, label: String) {
        // Prefer tapping the Button (Picker row is exposed as a button), then fall back to cell/other. Retry with scrolls.
        var target: XCUIElement? = nil
        func findTarget() -> XCUIElement? {
            if app.buttons[label].exists { return app.buttons[label] }
            if app.cells.containing(.staticText, identifier: label).element.exists {
                return app.cells.containing(.staticText, identifier: label).element
            }
            let other = app.otherElements.containing(.staticText, identifier: label).element
            if other.exists { return other }
            if app.staticTexts[label].exists { return app.staticTexts[label] }
            return nil
        }
        target = findTarget()
        var attempts = 0
        while target == nil && attempts < 3 {
            app.swipeUp()
            target = findTarget()
            attempts += 1
        }
        XCTAssertTrue(target?.waitForExistence(timeout: 5) == true)
        target?.tap()
    }

    /// Selects a value from the Lead Source picker robustly across presentation styles.
    private func selectLeadSource(_ app: XCUIApplication, option: String) {
        // Dismiss keyboard if open; it can block navigation push to picker list
        dismissKeyboardIfPresent(app)
        tapFormRow(app, label: "Lead Source")
        // Wait briefly for presentation
        _ = app.navigationBars["Lead Source"].waitForExistence(timeout: 1)
        // Try list-style presentation
        let optionCell = app.staticTexts[option]
        if optionCell.waitForExistence(timeout: 5) {
            optionCell.tap()
        } else if app.buttons[option].waitForExistence(timeout: 3) {
            app.buttons[option].tap()
        } else {
            // Try picker wheel
            let wheel = app.pickerWheels.element(boundBy: 0)
            if wheel.waitForExistence(timeout: 3) {
                wheel.adjust(toPickerWheelValue: option)
            } else {
                // It might not have opened due to keyboard; try again once after dismissing
                dismissKeyboardIfPresent(app)
                tapFormRow(app, label: "Lead Source")
                if optionCell.waitForExistence(timeout: 5) {
                    optionCell.tap()
                } else if app.buttons[option].waitForExistence(timeout: 3) {
                    app.buttons[option].tap()
                } else if wheel.waitForExistence(timeout: 3) {
                    wheel.adjust(toPickerWheelValue: option)
                } else {
                    // Last resort: search by predicate contains and try scrolling
                    let pred = NSPredicate(format: "label CONTAINS[c] %@", option)
                    var match = app.staticTexts.containing(pred).firstMatch
                    if !match.exists {
                        // Try within cells
                        match = app.cells.staticTexts.containing(pred).firstMatch
                    }
                    if !match.exists {
                        // Try buttons
                        match = app.buttons.containing(pred).firstMatch
                    }
                    if match.exists || match.waitForExistence(timeout: 2) {
                        match.tap()
                    } else {
                        // Attempt a couple scrolls on tables/collections then retry
                        if app.tables.element.exists { app.tables.element.swipeUp() }
                        if app.collectionViews.element.exists { app.collectionViews.element.swipeUp() }
                        match = app.staticTexts.containing(pred).firstMatch
                        if match.exists || match.waitForExistence(timeout: 2) {
                            match.tap()
                        } else {
                            XCTFail("Lead Source picker option \(option) not found")
                        }
                    }
                }
            }
        }
        // If we're on a pushed selection screen, navigate back to the form if needed
        let leadNav = app.navigationBars["Lead Source"]
        if leadNav.exists {
            let back = leadNav.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
    }

    private func dismissKeyboardIfPresent(_ app: XCUIApplication) {
        if app.keyboards.count > 0 {
            if app.toolbars.buttons["Done"].exists {
                app.toolbars.buttons["Done"].tap()
                return
            }
            // Tap navigation bar to end editing
            let nav = app.navigationBars["New Candidate"]
            if nav.exists { nav.tap() }
        }
    }

    /// Waits for a candidate entry containing the given text in the Follow Up list, retrying with small scrolls.
    @discardableResult
    private func waitForCandidateInFollowUp(_ app: XCUIApplication, contains text: String) -> XCUIElement {
        app.tabBars.buttons["Follow Up"].tap()
        XCTAssertTrue(app.navigationBars["Follow Up"].waitForExistence(timeout: 5))
        let pred = NSPredicate(format: "label CONTAINS[c] %@", text)
        func find() -> XCUIElement? {
            let btn = app.buttons.containing(pred).firstMatch
            if btn.exists { return btn }
            let txt = app.staticTexts.containing(pred).firstMatch
            if txt.exists { return txt }
            let other = app.otherElements.containing(pred).firstMatch
            return other.exists ? other : nil
        }
        var candidate = find()
        // Poll up to ~14 seconds with gentle scroll nudges to trigger LazyVStack rendering
        let timeout: TimeInterval = 14
        let start = Date()
        while candidate == nil && Date().timeIntervalSince(start) < timeout {
            // brief wait for layout
            _ = app.staticTexts.containing(pred).firstMatch.waitForExistence(timeout: 0.8)
            candidate = find()
            if candidate != nil { break }
            // nudge scroll view to populate more
            if app.scrollViews.element.exists { app.scrollViews.element.swipeUp() } else { app.swipeUp() }
            candidate = find()
            if candidate != nil { break }
            if app.scrollViews.element.exists { app.scrollViews.element.swipeDown() } else { app.swipeDown() }
            candidate = find()
        }
        if candidate == nil {
            // Force a simple refresh by toggling to the main tab and back
            if app.tabBars.buttons["Recruiting Tracker"].exists {
                app.tabBars.buttons["Recruiting Tracker"].tap()
                _ = app.navigationBars["Recruiting Tracker"].waitForExistence(timeout: 2)
                app.tabBars.buttons["Follow Up"].tap()
                _ = app.navigationBars["Follow Up"].waitForExistence(timeout: 2)
                candidate = find()
                if candidate == nil { _ = app.staticTexts.containing(pred).firstMatch.waitForExistence(timeout: 2); candidate = find() }
            }
        }
        guard let found = candidate else {
            XCTFail("Candidate containing \(text) not found in Follow Up")
            return app.staticTexts[text]
        }
        return found
    }
}

