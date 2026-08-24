@testable import Mia
import XCTest

final class SakanaAIProviderTests: XCTestCase {
    func testFetchUsageDecodesQuota() async throws {
        let body = """
        { "used": 8, "limit": 40 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = SakanaAIProvider(cookieHeader: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 8)
        XCTAssertEqual(usage?.limit, 40)
        XCTAssertEqual(usage?.unit, "requests")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = SakanaAIProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
