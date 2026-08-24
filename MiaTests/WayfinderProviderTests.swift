@testable import Mia
import XCTest

final class WayfinderProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 5, "limit": 100 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = try WayfinderProvider(apiKey: "key", baseURL: XCTUnwrap(URL(string: "http://127.0.0.1:8787")), client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 5)
        XCTAssertEqual(usage?.limit, 100)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = WayfinderProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
