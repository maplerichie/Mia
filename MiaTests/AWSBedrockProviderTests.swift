@testable import Mia
import XCTest

final class AWSBedrockProviderTests: XCTestCase {
    func testFetchUsageSendsSignedRequest() async throws {
        let stub = StubHTTPClient(outcome: .response(status: 200, body: Data()))
        let provider = AWSBedrockProvider(credentials: "AKIA:secret", client: stub)

        _ = try await provider.fetchUsage()
        let auth = stub.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNotNil(auth)
        XCTAssertTrue(auth?.hasPrefix("AWS4-HMAC-SHA256") == true)
        XCTAssertNotNil(stub.lastRequest?.value(forHTTPHeaderField: "x-amz-date"))
    }

    func testInvalidCredentialThrows() async {
        let provider = AWSBedrockProvider(credentials: "bad", client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .invalidCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSignatureIsDeterministicForSameDate() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let stub = StubHTTPClient(outcome: .response(status: 200, body: Data()))
        let provider = AWSBedrockProvider(
            credentials: "AKIA:secret",
            client: stub,
            dateProvider: { date }
        )

        _ = try await provider.fetchUsage()
        let auth1 = stub.lastRequest?.value(forHTTPHeaderField: "Authorization")

        _ = try await provider.fetchUsage()
        let auth2 = stub.lastRequest?.value(forHTTPHeaderField: "Authorization")

        XCTAssertEqual(auth1, auth2)
        XCTAssertTrue(auth1?.contains("/us-east-1/bedrock/aws4_request") == true)
    }
}
