import Foundation

/// Minimal HTTP client abstraction used by API-backed providers. Lets unit
/// tests inject a fake without touching `URLSession` directly.
protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.network("non-HTTP response")
        }
        return (data, http)
    }
}
