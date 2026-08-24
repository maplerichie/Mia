@testable import Mia
import XCTest

final class PoeProviderTests: XCTestCase {
    func testFetchUsageDecodesPoints() async throws {
        let body = """
        {
          "used_points": 100,
          "total_points": 1000
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = PoeProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 100)
        XCTAssertEqual(usage?.limit, 1000)
        XCTAssertEqual(usage?.unit, "points")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = PoeProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
