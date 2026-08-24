@testable import Mia
import XCTest

final class ElevenLabsProviderTests: XCTestCase {
    func testFetchUsageDecodesCharacters() async throws {
        let body = """
        {
          "character_usage": 1200,
          "character_limit": 40000
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ElevenLabsProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 1200)
        XCTAssertEqual(usage?.limit, 40000)
        XCTAssertEqual(usage?.unit, "characters")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "xi-api-key"), "key")
    }

    func testMissingCredentialThrows() async {
        let provider = ElevenLabsProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
