/*
 *  Copyright (c) Erik Doernenburg and contributors
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License.
 */

import XCTest

class MenuTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testMenuOpensPipeline() throws {
        let app = TestHelper.launchApp()
        let menu = TestHelper.openMenu(app: app)

        // Make sure broken URLs result in an alert to be shown
        menu.menuItems["connectfour"].click()
        XCTAssert(app.dialogs["alert"].staticTexts["Can't open web page"].exists)
        app.dialogs["alert"].buttons["Cancel"].click()
    }

    func _testMenuOpensAboutPanel() throws {
        let app = TestHelper.launchApp()
        let menu = TestHelper.openMenu(app: app)

        // Open about panel
        menu.menuItems["About CCMenu"].click()

        // Make sure version is displayed
        let versionText = app.dialogs.staticTexts.element(matching: NSPredicate(format: "value BEGINSWITH 'Version'"))
        let versionString = versionText.value as! String
        // TODO: Sometimes version check fails because the script that inserts it isn't run. Why?
        let range = versionString.range(of: "^Version [0-9]+.[0-9]+ \\([A-Z0-9]+\\)$", options: .regularExpression)
        XCTAssertNotNil(range)
    }

    func testAppearanceSettings() throws {
        let app = TestHelper.launchApp(pipelines: "ThreePipelines.json")
        let menu = TestHelper.openMenu(app: app)

        // Make sure expected pipelines are present
        XCTAssert(menu.menuItems["connectfour"].exists)
        XCTAssert(menu.menuItems["ccmenu"].exists)
        XCTAssert(menu.menuItems["ccmenu2 | Build and test"].exists)

        // Open settings, chose to hide pipelines with successful build, then close settings
        menu.menuItems["Settings..."].click()
        let window = app.windows["com_apple_SwiftUI_Settings_window"]
        window.toolbars.buttons["Appearance"].click()
        XCTAssert(window.checkBoxes["Hide successful builds"].isSelected == false)
        window.checkBoxes["Hide successful builds"].click()

        // Make sure the successful pipeline isn't show, and a hint is shown
        TestHelper.openMenu(app: app)
        XCTAssert(menu.menuItems["connectfour"].exists)
        XCTAssert(menu.menuItems["ccmenu2 | Build and test"].exists)
        XCTAssert(menu.menuItems["ccmenu"].exists == false)
        let hintItem = menu.menuItems["(1 pipeline hidden)"]
        XCTAssert(hintItem.exists)
        XCTAssert(hintItem.isEnabled == false)

        // Open settings, chose to display build labels, then close settings
        menu.menuItems["Settings..."].click() // otherwise click on first checkbox doesn't work
        XCTAssert(window.checkBoxes["Show label"].isSelected == false)
        window.checkBoxes["Show label"].click()
        XCTAssert(window.checkBoxes["Show time"].isSelected == false)
        window.checkBoxes["Show time"].click()

        // Make sure the pipeline menu item now displays the build label and relative time
        let buildTime = ISO8601DateFormatter().date(from: "2020-12-27T21:47:00Z")!
        let buildTimeRelative = buildTime.formatted(Date.RelativeFormatStyle(presentation: .named))
        TestHelper.openMenu(app: app)
        XCTAssert(menu.menuItems["connectfour \u{2014} \(buildTimeRelative), build.151"].exists)
    }

}
