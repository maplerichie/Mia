@testable import Mia
import XCTest

final class SyntheticProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 80, "limit": 500 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = SyntheticProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 80)
        XCTAssertEqual(usage?.limit, 500)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = SyntheticProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
