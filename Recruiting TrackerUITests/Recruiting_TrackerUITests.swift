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

        // Select a Lead Source (required) via table cell
        tapFormRow(app, label: "Lead Source")
        let indeed = app.staticTexts["Indeed"]
        XCTAssertTrue(indeed.waitForExistence(timeout: 10))
        indeed.tap()

        // Save
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Sheet should dismiss
        XCTAssertFalse(app.navigationBars["New Candidate"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddCandidateAppearsInFollowUp() {
        let app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresent(app)

        // Add candidate with name and needs follow-up enabled
        app.tabBars.buttons["Add"].tap()
        app.buttons["Tap to Add Candidate"].tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UITest FollowUp")

        tapFormRow(app, label: "Lead Source")
        app.staticTexts["Indeed"].tap()

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

        // Go to Follow Up tab and verify presence
        app.tabBars.buttons["Follow Up"].tap()
        XCTAssertTrue(app.staticTexts["UITest FollowUp"].waitForExistence(timeout: 5))
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
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap(); nameField.typeText("UITest Avoid")
        app.staticTexts["Lead Source"].tap()
        app.staticTexts["Indeed"].tap()
        if !app.switches["Needs Follow-up"].exists { app.swipeUp() }
        let followSwitch = app.switches["Needs Follow-up"]
        if followSwitch.value as? String == "0" { followSwitch.tap() }
        app.buttons["Save"].tap()

        // Open in Follow Up, then open candidate detail
        app.tabBars.buttons["Follow Up"].tap()
        let candidateCell = app.staticTexts["UITest Avoid"]
        XCTAssertTrue(candidateCell.waitForExistence(timeout: 5))
        candidateCell.tap()

        // Toggle Avoid Candidate -> expect alert, type reason, confirm
        let avoidToggle = app.switches["Avoid Candidate"]
        if !avoidToggle.exists { app.swipeUp() }
        XCTAssertTrue(avoidToggle.waitForExistence(timeout: 5))
        let preValue = (avoidToggle.value as? String) ?? "0"
        avoidToggle.tap()
        let reasonField = app.textFields["Reason for change"]
        XCTAssertTrue(reasonField.waitForExistence(timeout: 5))
        reasonField.tap(); reasonField.typeText("Automated test")
        let confirmButton = app.buttons["Mark as Avoid"]
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
        tapFormRow(app, label: "Lead Source")
        app.staticTexts["Indeed"].tap()
        if !app.switches["Needs Follow-up"].exists { app.swipeUp() }
        let followSwitch2 = app.switches["Needs Follow-up"]
        if followSwitch2.value as? String == "0" { followSwitch2.tap() }
        app.buttons["Save"].tap()

        // Navigate to Follow Up and open the first cell
        app.tabBars.buttons["Follow Up"].tap()
        XCTAssertTrue(app.cells.element(boundBy: 0).waitForExistence(timeout: 5))
        app.cells.element(boundBy: 0).tap()

        // Navigate to Attached Files (NavigationLink)
        var attachedFilesElement = app.staticTexts["Attached Files"]
        if !attachedFilesElement.exists { attachedFilesElement = app.buttons["Attached Files"] }
        if !attachedFilesElement.exists { app.swipeUp() }
        XCTAssertTrue(attachedFilesElement.waitForExistence(timeout: 5))
        attachedFilesElement.tap()

        // Verify Add Document button exists
        XCTAssertTrue(app.buttons["Add Document"].waitForExistence(timeout: 5))
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
        // SwiftUI Form rows are table cells; find by static text label
        let cell = app.tables.cells.containing(.staticText, identifier: label).element
        if !cell.exists { app.swipeUp() }
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
    }
}

