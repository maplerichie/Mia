@testable import Mia
import XCTest

final class DeepgramProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        { "used": 4.50, "balance": 25.50 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = DeepgramProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 4.50)
        XCTAssertEqual(usage?.limit, 25.50)
        XCTAssertEqual(usage?.unit, "USD")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Token key")
    }

    func testMissingCredentialThrows() async {
        let provider = DeepgramProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
