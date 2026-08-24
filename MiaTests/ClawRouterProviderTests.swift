@testable import Mia
import XCTest

final class ClawRouterProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        { "used": 12.34, "balance": 56.78 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ClawRouterProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 12.34)
        XCTAssertEqual(usage?.limit, 56.78)
        XCTAssertEqual(usage?.unit, "USD")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = ClawRouterProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
