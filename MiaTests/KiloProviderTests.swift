@testable import Mia
import XCTest

final class KiloProviderTests: XCTestCase {
    func testFetchUsageDecodesCredits() async throws {
        let body = """
        { "used": 15, "limit": 150 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = KiloProvider(cookieHeader: "session=abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 15)
        XCTAssertEqual(usage?.limit, 150)
        XCTAssertEqual(usage?.unit, "credits")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "session=abc")
    }

    func testFetchUsageReadsLocalFile() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try """
        { "used": 10, "limit": 100 }
        """.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let provider = KiloProvider(
            cookieHeader: nil,
            localFilePath: file.path,
            client: StubHTTPClient(outcome: .response(status: 200, body: Data()))
        )

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 10)
        XCTAssertEqual(usage?.limit, 100)
        XCTAssertEqual(usage?.unit, "credits")
    }

    func testMissingCredentialThrows() async {
        let provider = KiloProvider(cookieHeader: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
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
