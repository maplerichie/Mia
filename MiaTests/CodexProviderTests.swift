@testable import Mia
import XCTest

final class CodexProviderTests: XCTestCase {
    func testFetchUsageDecodesPrimaryWindow() async throws {
        let body = """
        {
          "rate_limit": {
            "primary_window": { "used": 25, "limit": 100 },
            "secondary_window": { "used": 150, "limit": 1000 }
          }
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = CodexProvider(accessToken: "tok", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 25)
        XCTAssertEqual(usage?.limit, 100)
        XCTAssertEqual(usage?.unit, "requests")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
    }

    func testMissingCredentialThrows() async {
        let provider = CodexProvider(accessToken: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
