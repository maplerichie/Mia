@testable import Mia
import XCTest

final class CrossModelProviderTests: XCTestCase {
    func testFetchUsageDecodesUsage() async throws {
        let body = """
        { "today": 1.23, "wallet_balance": 45.67 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = CrossModelProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 1.23)
        XCTAssertEqual(usage?.limit, 45.67)
        XCTAssertEqual(usage?.unit, "USD")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = CrossModelProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
