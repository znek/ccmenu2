/*
 *  Copyright (c) Erik Doernenburg and contributors
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License.
 */

import XCTest
import Hummingbird
import HummingbirdAuth

class CCTrayTests: XCTestCase {
    
    var webapp: HBApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        webapp = try TestHelper.startEmbeddedServer()
    }

    override func tearDownWithError() throws {
        webapp.stop()
    }

    func testShowsPipelineStatusFetchedFromServer() throws {
        webapp.router.get("/cctray.xml") { _ in """
            <Projects>
                <Project activity='Sleeping' lastBuildLabel='build.888' lastBuildStatus='Success' lastBuildTime='2024-02-11T23:19:26+01:00' name='connectfour'></Project>
            </Projects>
        """}

        let app = TestHelper.launchApp(pipelines: "CCTrayPipeline.json", pauseMonitor: false)
        let window = app.windows["Pipelines"]

        // Find the status description field (there's only one because there's only one pipeline), then
        // wait for the update to the build label to show the label return with the embedded server
        let descriptionText = window.tables.staticTexts["Status description"]
        expectation(for: NSPredicate(format: "value CONTAINS 'Label: build.888'"), evaluatedWith: descriptionText)
        waitForExpectations(timeout: 5)

        // Now stop the server and make sure the error shows quickly.
        // TODO: Will this ever not work? Our embedded server might use different caching logic.
        webapp.stop()
        expectation(for: NSPredicate(format: "value CONTAINS 'Could not connect to the server.'"), evaluatedWith: descriptionText)
        waitForExpectations(timeout: 2)
    }

    func testShowsErrorWhenFeedDoesntContainProject() throws {
        webapp.router.get("/cctray.xml") { _ in """
            <Projects>
                <Project activity='Sleeping' lastBuildStatus='Success' lastBuildTime='2024-02-11T23:19:26+01:00' name='other-project'></Project>
            </Projects>
        """}

        let app = TestHelper.launchApp(pipelines: "CCTrayPipeline.json", pauseMonitor: false)
        let window = app.windows["Pipelines"]

        // Find the status description field (there's only one because there's only one pipeline), then
        // wait for the update to the status text displaying the error message
        let descriptionText = window.tables.staticTexts["Status description"]
        expectation(for: NSPredicate(format: "value CONTAINS 'The server did not provide a status'"), evaluatedWith: descriptionText)
        waitForExpectations(timeout: 5)
    }

    func testShowsErrorForHTTPError() throws {
        let app = TestHelper.launchApp(pipelines: "CCTrayPipeline.json", pauseMonitor: false)
        let window = app.windows["Pipelines"]

        // Find the status description field (there's only one because there's only one pipeline), then
        // wait for the error meesage from the embedded server, which is not found because we didn't
        // register any routes
        let descriptionText = window.tables.staticTexts["Status description"]
        expectation(for: NSPredicate(format: "value CONTAINS 'The server responded: not found'"), evaluatedWith: descriptionText)
        waitForExpectations(timeout: 5)
    }

    func testAddsPipeline() throws {
        webapp.router.get("/cctray.xml") { _ in """
            <Projects>
                <Project activity='Sleeping' lastBuildStatus='Success' lastBuildTime='2024-02-11T23:19:26+01:00' name='other-project'></Project>
                <Project activity='Sleeping' lastBuildLabel='build.888' lastBuildStatus='Success' lastBuildTime='2024-02-11T23:19:26+01:00' name='connectfour'></Project>
            </Projects>
        """}

        let app = TestHelper.launchApp(pipelines: "EmptyPipelines.json", pauseMonitor: false)
        let window = app.windows["Pipelines"]
        let sheet = window.sheets.firstMatch

        // Navigate to add project sheet and enter minimal feed URL
        window.toolbars.popUpButtons["Add pipeline menu"].click()
        window.toolbars.menuItems["Add project from CCTray feed..."].click()
        let urlField = sheet.textFields["Server URL field"]
        urlField.click()
        sheet.typeText("localhost:8086\n")

        // Make sure that the scheme gets added to the URL, the path is discovered, that
        // the picker shows the first project in alphabetical order, and the default display
        // name is set
        let projectPicker = sheet.popUpButtons["Project picker"]
        let displayNameField = sheet.textFields["Display name field"]
        expectation(for: NSPredicate(format: "value == 'http://localhost:8086/cctray.xml'"), evaluatedWith: urlField)
        expectation(for: NSPredicate(format: "value == 'connectfour'"), evaluatedWith: projectPicker)
        expectation(for: NSPredicate(format: "value == 'connectfour'"), evaluatedWith: displayNameField)
        waitForExpectations(timeout: 2)

        // Set a custom display name, and close the sheet
        displayNameField.doubleClick()
        sheet.typeText("C4")
        sheet.buttons["Apply"].click()

        // Make sure the pipeline is shown, and that its status is fetched immediately
        let titleText = window.tables.staticTexts["Pipeline title"]
        expectation(for: NSPredicate(format: "value == 'C4'"), evaluatedWith: titleText)
        let descriptionText = window.tables.staticTexts["Status description"]
        expectation(for: NSPredicate(format: "value CONTAINS 'Label: build.888'"), evaluatedWith: descriptionText)
        waitForExpectations(timeout: 2)
    }


    func testAddsPipelineWithAuthentication() throws {
        webapp.router.get("/cctray.xml") { request in
            guard request.authBasic?.username == "dev" && request.authBasic?.password == "rosebud" else {
                throw HBHTTPError(.unauthorized)
            }
            return """
            <Projects>
                <Project activity='Sleeping' lastBuildLabel='build.888' lastBuildStatus='Success' lastBuildTime='2024-02-11T23:19:26+01:00' name='connectfour'></Project>
            </Projects>
        """}

        let app = TestHelper.launchApp(pipelines: "EmptyPipelines.json")
        let window = app.windows["Pipelines"]
        let sheet = window.sheets.firstMatch

        // Navigate to add project sheet and enter login data and full feed URL
        window.toolbars.popUpButtons["Add pipeline menu"].click()
        window.toolbars.menuItems["Add project from CCTray feed..."].click()
        sheet.checkBoxes["Basic auth toggle"].click()
        sheet.textFields["User field"].click()
        sheet.typeText("dev")
        sheet.secureTextFields["Password field"].click()
        sheet.typeText("rosebud")
        sheet.textFields["Server URL field"].click()
        sheet.typeText("http://localhost:8086/cctray.xml\n")

        // Make sure that the picker shows the first project in alphabetical order
        let projectPicker = sheet.popUpButtons["Project picker"]
        expectation(for: NSPredicate(format: "value == 'connectfour'"), evaluatedWith: projectPicker)
        waitForExpectations(timeout: 2)
    }

    func testShowsErrorWhenAddingPipelineWithAuthenticationButMissingLogin() throws {
        webapp.router.get("/cctray.xml") { request in
            guard request.authBasic?.username == "dev" && request.authBasic?.password == "rosebud" else {
                throw HBHTTPError(.unauthorized)
            }
            return ""
        }

        let app = TestHelper.launchApp(pipelines: "EmptyPipelines.json")
        let window = app.windows["Pipelines"]
        let sheet = window.sheets.firstMatch

        // Navigate to add project sheet and enter full feed URL
        window.toolbars.popUpButtons["Add pipeline menu"].click()
        window.toolbars.menuItems["Add project from CCTray feed..."].click()
        sheet.textFields["Server URL field"].click()
        sheet.typeText("http://localhost:8086/cctray.xml\n")

        // Make sure that the picker shows an error message containing the word "unauthorized".
        let projectPicker = sheet.popUpButtons["Project picker"]
        expectation(for: NSPredicate(format: "value CONTAINS 'unauthorized'"), evaluatedWith: projectPicker)
        waitForExpectations(timeout: 2)
    }

}
