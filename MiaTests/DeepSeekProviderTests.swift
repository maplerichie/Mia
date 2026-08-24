@testable import Mia
import XCTest

final class DeepSeekProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        {
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "12.50",
              "granted_balance": "2.50",
              "topped_up_balance": "10.00"
            }
          ]
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = DeepSeekProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 10.0)
        XCTAssertEqual(usage?.limit, 12.5)
        XCTAssertEqual(usage?.unit, "USD")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = DeepSeekProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
