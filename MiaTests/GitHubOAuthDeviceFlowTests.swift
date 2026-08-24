import XCTest
@testable import Mia

final class GitHubOAuthDeviceFlowTests: XCTestCase {
    func testStartDeviceFlowParsesResponse() async throws {
        let body = Data("""
        device_code=dev_123&user_code=USR-456&verification_uri=https://github.com/login/device&expires_in=900&interval=5
        """.utf8)
        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let flow = GitHubOAuthDeviceFlow(clientID: "client-id", client: stub)

        let deviceCode = try await flow.startDeviceFlow()
        XCTAssertEqual(deviceCode.deviceCode, "dev_123")
        XCTAssertEqual(deviceCode.userCode, "USR-456")
        XCTAssertEqual(deviceCode.verificationURI.absoluteString, "https://github.com/login/device")
        XCTAssertEqual(deviceCode.interval, 5)
        XCTAssertEqual(deviceCode.expiresIn, 900)

        let requestBody = stub.lastRequest?.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(requestBody, "client_id=client-id&scope=read:user,copilot")
    }

    func testPollForTokenReturnsAccessToken() async throws {
        let pending = Data("error=authorization_pending".utf8)
        let token = Data("access_token=gho_abc&token_type=bearer&refresh_token=ghr_def".utf8)

        let stub = SequencedStubHTTPClient(responses: [
            SequencedStubHTTPClient.Response(status: 200, body: pending),
            SequencedStubHTTPClient.Response(status: 200, body: token)
        ])
        let flow = GitHubOAuthDeviceFlow(clientID: "client-id", client: stub)

        let result = try await flow.pollForToken(deviceCode: "dev_123", interval: 0.01)
        XCTAssertEqual(result.accessToken, "gho_abc")
        XCTAssertEqual(result.refreshToken, "ghr_def")
        XCTAssertEqual(result.tokenType, "bearer")
    }

    func testPollForTokenThrowsOnOAuthError() async {
        let body = Data("error=access_denied".utf8)
        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let flow = GitHubOAuthDeviceFlow(clientID: "client-id", client: stub)

        do {
            _ = try await flow.pollForToken(deviceCode: "dev_123", interval: 0.01)
            XCTFail("expected throw")
        } catch let error as ProviderError {
            if case .other(let message) = error {
                XCTAssertTrue(message.contains("access_denied"))
            } else {
                XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

private final class SequencedStubHTTPClient: HTTPClient, @unchecked Sendable {
    struct Response {
        let status: Int
        let body: Data
    }

    private var responses: [Response]
    private(set) var lastRequest: URLRequest?

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        guard !responses.isEmpty else {
            throw ProviderError.other("no more responses")
        }
        let next = responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (next.body, response)
    }
}
