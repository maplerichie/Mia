@testable import Mia
import XCTest

final class MoonshotProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        {
          "used": 50,
          "available": 450
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = MoonshotProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 50)
        XCTAssertEqual(usage?.limit, 450)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = MoonshotProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
