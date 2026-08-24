@testable import Mia
import XCTest

final class OpenCodeProviderTests: XCTestCase {
    func testFetchUsageDecodesTokens() async throws {
        let body = """
        { "used": 600, "limit": 6000 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = OpenCodeProvider(cookieHeader: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 600)
        XCTAssertEqual(usage?.limit, 6000)
        XCTAssertEqual(usage?.unit, "tokens")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = OpenCodeProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
