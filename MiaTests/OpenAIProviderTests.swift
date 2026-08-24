import XCTest
@testable import Mia

final class OpenAIProviderTests: XCTestCase {
    func testFetchUsageSumsTokens() async throws {
        let body = """
        {
          "object": "page",
          "data": [
            {
              "object": "bucket",
              "start_time": 1714521600,
              "end_time": 1714608000,
              "results": [
                { "input_tokens": 1500, "output_tokens": 500 }
              ]
            },
            {
              "object": "bucket",
              "start_time": 1714608000,
              "end_time": 1714694400,
              "results": [
                { "input_tokens": 2000, "output_tokens": 1000 }
              ]
            }
          ],
          "has_more": false
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = OpenAIProvider(apiKey: "sk-admin-test", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 5000)
        XCTAssertEqual(usage?.unit, "tokens")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-admin-test")
    }

    func testMissingCredentialThrows() async {
        let provider = OpenAIProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInvalidCredentialMaps401() async {
        let stub = StubHTTPClient(outcome: .response(status: 401, body: Data()))
        let provider = OpenAIProvider(apiKey: "bad", client: stub)
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .invalidCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRateLimitedMaps429() async {
        let stub = StubHTTPClient(outcome: .response(status: 429, body: Data()))
        let provider = OpenAIProvider(apiKey: "key", client: stub)
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMalformedResponseThrowsDecoding() async {
        let body = Data("not json".utf8)
        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = OpenAIProvider(apiKey: "key", client: stub)

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
}
