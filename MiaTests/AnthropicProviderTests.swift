import XCTest
@testable import Mia

final class AnthropicProviderTests: XCTestCase {
    func testFetchUsageSumsTokens() async throws {
        let body = """
        {
          "data": [
            {
              "starting_at": "2026-05-01T00:00:00Z",
              "ending_at": "2026-05-02T00:00:00Z",
              "results": [
                {
                  "uncached_input_tokens": 1000,
                  "cache_read_input_tokens": 200,
                  "cache_creation_input_tokens": 50,
                  "output_tokens": 750
                }
              ]
            },
            {
              "starting_at": "2026-05-02T00:00:00Z",
              "ending_at": "2026-05-03T00:00:00Z",
              "results": [
                {
                  "uncached_input_tokens": 0,
                  "cache_read_input_tokens": 0,
                  "cache_creation_input_tokens": 0,
                  "output_tokens": 0
                }
              ]
            }
          ],
          "has_more": false
        }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = AnthropicProvider(apiKey: "sk-admin-test", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 2000)
        XCTAssertEqual(usage?.unit, "tokens")
        XCTAssertNil(usage?.limit)

        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "x-api-key"), "sk-admin-test")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "anthropic-version"), AnthropicProvider.apiVersion)
    }

    func testMissingCredentialThrows() async {
        let provider = AnthropicProvider(apiKey: "", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
        let provider = AnthropicProvider(apiKey: "bad", client: stub)
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
        let provider = AnthropicProvider(apiKey: "key", client: stub)
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCurrentMonthRangeCoversFullMonth() {
        let comps = DateComponents(year: 2026, month: 5, day: 7, hour: 12)
        let reference = Calendar.iso8601UTC.date(from: comps)!
        let (start, end) = AnthropicProvider.currentMonthRange(reference: reference)
        let startComps = Calendar.iso8601UTC.dateComponents([.year, .month, .day], from: start)
        let endComps = Calendar.iso8601UTC.dateComponents([.year, .month, .day], from: end)
        XCTAssertEqual(startComps.year, 2026)
        XCTAssertEqual(startComps.month, 5)
        XCTAssertEqual(startComps.day, 1)
        XCTAssertEqual(endComps.year, 2026)
        XCTAssertEqual(endComps.month, 6)
        XCTAssertEqual(endComps.day, 1)
    }
}
