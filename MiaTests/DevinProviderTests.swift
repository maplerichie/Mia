@testable import Mia
import XCTest

final class DevinProviderTests: XCTestCase {
    func testFetchUsageDecodesDailyQuota() async throws {
        let body = """
        {
          "daily": { "used": 3, "limit": 10 },
          "weekly": { "used": 15, "limit": 50 }
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = DevinProvider(cookieHeader: "auth1_session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 3)
        XCTAssertEqual(usage?.limit, 10)
        XCTAssertEqual(usage?.unit, "requests")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "auth1_session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = DevinProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
