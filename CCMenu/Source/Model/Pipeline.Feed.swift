/*
 *  Copyright (c) Erik Doernenburg and contributors
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License.
 */

import Foundation

extension Pipeline {

    // TODO: Should this be inside Feed?
    enum FeedType: String, Codable {
        case
        cctray,
        github
    }

    struct Feed: Codable, Equatable {
        var type: FeedType
        var url: String
        var name: String?       // for cctray only: name of the project in the feed
        var pauseUntil: Int?    // for GitHub only (so far): when to try polling again

        static func == (lhs: Pipeline.Feed, rhs: Pipeline.Feed) -> Bool {
            (lhs.type == rhs.type) && (lhs.url == rhs.url) && (lhs.name == rhs.name)
        }

        mutating func setPauseUntil(_ epochSeconds: Int) {
            pauseUntil = epochSeconds
        }

        mutating func clearPauseUntil() {
            pauseUntil = nil
        }

    }
    
}
