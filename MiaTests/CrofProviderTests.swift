@testable import Mia
import XCTest

final class CrofProviderTests: XCTestCase {
    func testFetchUsageDecodesRequests() async throws {
        let body = """
        {
          "credits": 25.0,
          "requests_plan": { "used": 80, "total": 100 },
          "usable_requests": 20
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = CrofProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 80)
        XCTAssertEqual(usage?.limit, 100)
        XCTAssertEqual(usage?.unit, "requests")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = CrofProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
