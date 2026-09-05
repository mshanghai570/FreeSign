//
//  FreeSignUITests.swift
//  FreeSignUITests
//

import XCTest

final class FreeSignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllPrimaryTabsAndAssistantsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        for tabName in ["Library", "Sources", "Apps", "Files", "Settings"] {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(tabName) tab should exist")
            tab.tap()

            let assistant = app.buttons["tabAssistant.\(tabName)"]
            XCTAssertTrue(
                assistant.waitForExistence(timeout: 5),
                "\(tabName) should expose its tab-aware Lab Assistant"
            )
        }
    }

    @MainActor
    func testSettingsCertificateManagementControlsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let manageCertificates = app.buttons["settings.manageCertificates"]
        XCTAssertTrue(manageCertificates.waitForExistence(timeout: 5))
        manageCertificates.tap()

        let importP12 = app.buttons["certificates.importP12"]
        XCTAssertTrue(
            importP12.waitForExistence(timeout: 5),
            "Certificate management should retain an Import P12 control when opened from Settings"
        )
    }

    @MainActor
    func testSettingsTabDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "App should remain alive after opening Settings")
    }
}
