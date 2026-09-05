//
//  FreeSignUITests.swift
//  FreeSignUITests
//
//  Created by Michael Shingara on 7/30/26.
//

import XCTest

final class FreeSignUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsTabDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab should exist")
        settingsTab.tap()

        // Give the settings view time to render fully
        sleep(3)

        // If the app crashed, this query will fail the test.
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "App should still be alive after opening Settings")
    }

    @MainActor
    func testAllTabsDoNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        for tabName in ["Library", "Sources", "Apps", "Files", "Settings"] {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab \(tabName) should exist")
            tab.tap()
            sleep(2)
            XCTAssertTrue(app.tabBars.buttons[tabName].exists, "App should be alive after opening \(tabName)")
        }
    }
}
