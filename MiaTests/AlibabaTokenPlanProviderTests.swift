@testable import Mia
import XCTest

final class AlibabaTokenPlanProviderTests: XCTestCase {
    func testFetchUsageDecodesTokens() async throws {
        let body = """
        { "used": 50000, "limit": 200000 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = AlibabaTokenPlanProvider(credential: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 50000)
        XCTAssertEqual(usage?.limit, 200_000)
        XCTAssertEqual(usage?.unit, "tokens")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = AlibabaTokenPlanProvider(credential: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
