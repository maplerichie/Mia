@testable import Mia
import XCTest

final class ZedProviderTests: XCTestCase {
    func testFetchUsageDecodesEditPredictions() async throws {
        let body = """
        {
          "plan": {
            "plan_v3": "Pro",
            "usage": {
              "edit_predictions": { "used": 42, "limit": 500 }
            },
            "has_overdue_invoices": false
          }
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ZedProvider(userID: "123", accessToken: "tok", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 42)
        XCTAssertEqual(usage?.limit, 500)
        XCTAssertEqual(usage?.unit, "edit predictions")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "123 tok")
    }

    func testMissingCredentialThrows() async {
        let provider = ZedProvider(userID: nil, accessToken: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
