/*
 *  Copyright (c) Erik Doernenburg and contributors
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use these files except in compliance with the License.
 */

import Foundation

enum GithHubFeedReaderError: LocalizedError {
    case invalidURLError
    case httpError(Int)
    case rateLimitError(Int)
    case noStatusError

    public var errorDescription: String? {
        switch self {
        case .invalidURLError:
            return NSLocalizedString("invalid URL", comment: "")
        case .httpError(let statusCode):
            return HTTPURLResponse.localizedString(forStatusCode: statusCode)
        case .rateLimitError(let timestamp):
            let date = Date(timeIntervalSince1970: Double(timestamp)).formatted(date: .omitted, time: .shortened)
            return String(format: NSLocalizedString("Rate limit exceeded. Next update at %@.", comment: ""), date)
        case .noStatusError:
            return "No status available for this pipeline."
        }
    }
}


class GitHubFeedReader {

    private(set) var pipeline: Pipeline

    public init(for pipeline: Pipeline) {
        self.pipeline = pipeline
    }

    public func updatePipelineStatus() async {
        do {
            let token = try Keychain().getToken(forService: "GitHub")
            if let pauseUntil = pipeline.feed.pauseUntil {
                guard Date().timeIntervalSince1970 >= Double(pauseUntil) else {
                    return
                }
                pipeline.feed.clearPauseUntil()
            }
            guard let request = GitHubAPI.requestForFeed(feed: pipeline.feed, token: token) else {
                throw GithHubFeedReaderError.invalidURLError
            }
            guard let newStatus = try await fetchStatus(request: request) else {
                throw GithHubFeedReaderError.noStatusError
            }
            pipeline.status = newStatus
            pipeline.connectionError = nil
        } catch {
            if let error = error as? GithHubFeedReaderError, case .rateLimitError(let pauseUntil) = error {
                pipeline.feed.setPauseUntil(pauseUntil)
            }
            pipeline.status = Pipeline.Status(activity: .other)
            pipeline.connectionError = error.localizedDescription
        }
    }


    private func fetchStatus(request: URLRequest) async throws -> Pipeline.Status? {
        let (data, response) = try await URLSession.feedSession.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.unsupportedURL)
        }
        guard response.statusCode != 403 && response.statusCode != 429 else {
            guard let v = response.value(forHTTPHeaderField: "x-ratelimit-remaining"), Int(v) == 0 else {
                throw GithHubFeedReaderError.httpError(response.statusCode)
            }
            guard let v = response.value(forHTTPHeaderField: "x-ratelimit-reset"), let pauseUntil = Int(v) else {
                throw GithHubFeedReaderError.httpError(response.statusCode)
            }
            throw GithHubFeedReaderError.rateLimitError(pauseUntil)
        }
        guard response.statusCode == 200 else {
            throw GithHubFeedReaderError.httpError(response.statusCode)
        }
        let parser = GitHubResponseParser()
        try parser.parseResponse(data)
        return parser.pipelineStatus(name: pipeline.name)
    }

}
