@testable import Mia
import XCTest

final class ClaudeProviderTests: XCTestCase {
    func testFetchUsageDecodesPrimaryWindow() async throws {
        let body = """
        {
          "rate_limit": {
            "primary_window": { "used": 8, "limit": 45 },
            "secondary_window": { "used": 120, "limit": 350 }
          }
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ClaudeProvider(accessToken: "tok", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 8)
        XCTAssertEqual(usage?.limit, 45)
        XCTAssertEqual(usage?.unit, "messages")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    func testMissingCredentialThrows() async {
        let provider = ClaudeProvider(accessToken: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
