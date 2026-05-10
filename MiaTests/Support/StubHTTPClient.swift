import Foundation
@testable import Mia

/// Stub `HTTPClient` for provider tests. Records the issued request and
/// replays the configured response.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    enum Outcome {
        case response(status: Int, body: Data)
        case failure(Error)
    }

    private let outcome: Outcome
    private(set) var lastRequest: URLRequest?

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        switch outcome {
        case .response(let status, let body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (body, response)
        case .failure(let error):
            throw error
        }
    }
}
