import Foundation

/// Shared helpers that reduce boilerplate across API and cookie-based providers.
enum ProviderHTTP {
    /// Hardcoded provider URLs are compile-time constants. This helper keeps
    /// the force unwrap in one place and documents it.
    static func hardcodedURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid hardcoded provider URL: \(string)")
        }
        return url
    }
    /// Maps HTTP status codes to typed provider errors.
    static func validate(response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200 ... 299: return
        case 401, 403: throw ProviderError.invalidCredential
        case 429: throw ProviderError.rateLimited
        default:
            throw ProviderError.network("HTTP \(response.statusCode)")
        }
    }

    /// Validates `response` and decodes `data` as `T`, wrapping decoding errors
    /// as `ProviderError.decoding`.
    static func validatedResponse<T: Decodable>(
        _ type: T.Type,
        data: Data,
        response: HTTPURLResponse
    ) throws -> T {
        try validate(response: response)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ProviderError.decoding(String(describing: error))
        }
    }

    /// Performs the request, validates the response, and decodes the JSON body
    /// in one step. Returns both the decoded payload and the raw response data
    /// so callers can store `rawJSON` for diagnostics.
    static func fetchJSON<T: Decodable>(
        _ type: T.Type,
        request: URLRequest,
        client: HTTPClient
    ) async throws -> (payload: T, data: Data) {
        let (data, response) = try await client.data(for: request)
        let payload = try validatedResponse(type, data: data, response: response)
        return (payload, data)
    }
}
