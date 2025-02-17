/*
 *  Copyright (c) Erik Doernenburg and contributors
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License.
 */

import XCTest
@testable import CCMenu

final class PipelineRowModelTests: XCTestCase {

    private func makePipeline(name: String = "connectfour", activity: Pipeline.Activity = .other) -> Pipeline {
        var p = Pipeline(name: name, feed: Pipeline.Feed(type: .cctray, url: "http://localhost:4567/cc.xml", name: name))
        p.status.activity = activity
        return p
    }

    func testStatusWhenSleepingAndLastBuildNotAvailable() throws {
        let pipeline = makePipeline(activity: .sleeping)
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertEqual("Waiting for first build", pvm.statusDescription)
    }

    func testStatusWhenSleepingAndLastBuildIsAvailable() throws {
        var pipeline = makePipeline(activity: .sleeping)
        pipeline.status.lastBuild = Build(result: .success)
        pipeline.status.lastBuild!.label = "842"
        pipeline.status.lastBuild!.timestamp = ISO8601DateFormatter().date(from: "2020-12-27T21:47:00Z")
        pipeline.status.lastBuild!.duration = 53
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        // Check some components that should definitely be there in this form
        XCTAssertTrue(pvm.statusDescription.contains("2020")) // timestamp year
        XCTAssertTrue(pvm.statusDescription.contains("27"))   // timestamp day
        XCTAssertTrue(pvm.statusDescription.contains("47"))   // timestamp minute
        XCTAssertTrue(pvm.statusDescription.contains("842"))  // label
        XCTAssertTrue(pvm.statusDescription.contains("53"))   // duration
    }

    func testStatusWhenSleepingAndLastBuildIsAvailableButHasNoFurtherInformation() throws {
        var pipeline = makePipeline(activity: .sleeping)
        pipeline.status.lastBuild = Build(result: .success)
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertEqual("Build finished", pvm.statusDescription)
    }

    func testStatusWhenBuildingAndCurrentBuildIsAvailable() throws {
        var pipeline = makePipeline(activity: .building)
        let date = ISO8601DateFormatter().date(from: "2020-12-27T21:47:00Z")!
        pipeline.status.currentBuild = Build(result: .unknown, timestamp: date)
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        let time = date.formatted(date: .omitted, time: .shortened)
        XCTAssertTrue(pvm.statusDescription.contains(time))
    }

    func testStatusWhenBuildingAndCurrentBuildAndLastBuildWhichWasSuccessfulAndHasDurationAreAvailable() throws {
        var pipeline = makePipeline(activity: .building)
        let date = ISO8601DateFormatter().date(from: "2020-12-27T21:47:00Z")
        pipeline.status.currentBuild = Build(result: .unknown, timestamp: date)
        pipeline.status.lastBuild = Build(result: .success, duration: 310)
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertTrue(pvm.statusDescription.contains("Last build time: 5m 10s"))
    }

    func testStatusWhenBuildingAndCurrentBuildAndLastBuildWhichWasFailureAndHasDurationAreAvailable() throws {
        var pipeline = makePipeline(activity: .building)
        let date = ISO8601DateFormatter().date(from: "2020-12-27T21:47:00Z")
        pipeline.status.currentBuild = Build(result: .unknown, timestamp: date)
        pipeline.status.lastBuild = Build(result: .failure, duration: 40)
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertTrue(pvm.statusDescription.contains("Last build time: failed after 40s"))
    }

    func testStatusWhenErrorIsSet() throws {
        var pipeline = makePipeline(activity: .sleeping)
        pipeline.status.lastBuild = Build(result: .success)
        pipeline.connectionError = "404 Not Found"
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertEqual("\u{1F53A} 404 Not Found", pvm.statusDescription)
    }

    func testUrlWhenCCTrayHasUserAssignedName() throws {
        var pipeline = makePipeline(activity: .sleeping)
        pipeline.name = "Connect4"
        let pvm = PipelineRowViewModel(pipeline: pipeline)

        XCTAssertEqual("http://localhost:4567/cc.xml (connectfour)", pvm.feedUrl)
    }

}
