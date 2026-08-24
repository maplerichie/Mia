@testable import Mia
import XCTest

final class KimiK2ProviderTests: XCTestCase {
    func testFetchUsageDecodesBalance() async throws {
        let body = """
        { "consumed": 100, "remaining": 400 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = KimiK2Provider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 100)
        XCTAssertEqual(usage?.limit, 500)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = KimiK2Provider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
