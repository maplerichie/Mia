@testable import Mia
import XCTest

final class CodebuffProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 50, "limit": 200 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = CodebuffProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 50)
        XCTAssertEqual(usage?.limit, 200)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = CodebuffProvider(apiKey: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
