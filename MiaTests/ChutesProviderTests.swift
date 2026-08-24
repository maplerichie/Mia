import XCTest
@testable import Mia

final class ChutesProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 40, "limit": 200 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ChutesProvider(apiKey: "key", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 40)
        XCTAssertEqual(usage?.limit, 200)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    func testMissingCredentialThrows() async {
        let provider = ChutesProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMalformedResponseThrowsDecoding() async {
        let body = Data("not json".utf8)
        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = ChutesProvider(apiKey: "key", client: stub)

        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            if case .decoding = error {} else {
                XCTFail("expected decoding error, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRateLimitThrows() async {
        let stub = StubHTTPClient(outcome: .response(status: 429, body: Data()))
        let provider = ChutesProvider(apiKey: "key", client: stub)

        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testNetworkErrorThrows() async {
        struct FakeError: Error {}
        let stub = StubHTTPClient(outcome: .failure(FakeError()))
        let provider = ChutesProvider(apiKey: "key", client: stub)

        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch is FakeError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
