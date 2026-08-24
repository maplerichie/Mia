@testable import Mia
import XCTest

final class DroidFactoryProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 200, "limit": 1000 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = DroidFactoryProvider(cookieHeader: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 200)
        XCTAssertEqual(usage?.limit, 1000)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = DroidFactoryProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
