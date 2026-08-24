@testable import Mia
import XCTest

final class VeniceProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        { "balance": 50.0, "used": 10.0, "currency": "USD" }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = VeniceProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 10.0)
        XCTAssertEqual(usage?.limit, 50.0)
        XCTAssertEqual(usage?.unit, "USD")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = VeniceProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
