@testable import Mia
import XCTest

final class T3ChatProviderTests: XCTestCase {
    func testFetchUsageDecodesBaseBucket() async throws {
        let body = """
        { "base": { "used": 12, "limit": 50 } }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = T3ChatProvider(cookieHeader: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 12)
        XCTAssertEqual(usage?.limit, 50)
        XCTAssertEqual(usage?.unit, "messages")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testMissingCredentialThrows() async {
        let provider = T3ChatProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
