@testable import Mia
import XCTest

final class CursorProviderTests: XCTestCase {
    func testFetchUsageDecodesUsageSummary() async throws {
        let body = """
        {
          "usage": { "used": 30, "limit": 150 }
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = CursorProvider(cookieHeader: "WorkosCursorSessionToken=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 30)
        XCTAssertEqual(usage?.limit, 150)
        XCTAssertEqual(usage?.unit, "requests")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "WorkosCursorSessionToken=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = CursorProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
