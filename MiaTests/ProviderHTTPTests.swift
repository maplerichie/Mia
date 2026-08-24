import Foundation
@testable import Mia
import XCTest

final class ProviderHTTPTests: XCTestCase {
    func testValidateAccepts2xx() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertNoThrow(try ProviderHTTP.validate(response: response))
    }

    func testValidate401MapsToInvalidCredential() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validate(response: response)) { error in
            XCTAssertEqual(error as? ProviderError, .invalidCredential)
        }
    }

    func testValidate403MapsToInvalidCredential() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validate(response: response)) { error in
            XCTAssertEqual(error as? ProviderError, .invalidCredential)
        }
    }

    func testValidate429MapsToRateLimited() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validate(response: response)) { error in
            XCTAssertEqual(error as? ProviderError, .rateLimited)
        }
    }

    func testValidate500MapsToNetworkError() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validate(response: response)) { error in
            if case .network(let detail) = error as? ProviderError {
                XCTAssertTrue(detail.contains("500"))
            } else {
                XCTFail("expected network error, got \(String(describing: error))")
            }
        }
    }

    func testValidatedResponseDecodesJSON() throws {
        struct Payload: Decodable, Equatable {
            let value: Int
        }
        let data = Data("{\"value\":42}".utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let payload = try ProviderHTTP.validatedResponse(Payload.self, data: data, response: response)
        XCTAssertEqual(payload, Payload(value: 42))
    }

    func testValidatedResponseWrapsDecodingError() throws {
        struct Payload: Decodable {}
        let data = Data("not json".utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validatedResponse(Payload.self, data: data, response: response)) { error in
            if case .decoding = error as? ProviderError {} else {
                XCTFail("expected decoding error, got \(String(describing: error))")
            }
        }
    }

    func testValidatedResponsePropagatesValidationError() throws {
        struct Payload: Decodable {}
        let data = Data()
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(try ProviderHTTP.validatedResponse(Payload.self, data: data, response: response)) { error in
            XCTAssertEqual(error as? ProviderError, .invalidCredential)
        }
    }

    func testHardcodedURLReturnsURLForValidString() {
        let url = ProviderHTTP.hardcodedURL("https://example.com/path")
        XCTAssertEqual(url.absoluteString, "https://example.com/path")
    }
}
