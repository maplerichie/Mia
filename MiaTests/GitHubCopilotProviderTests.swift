import XCTest
@testable import Mia

final class GitHubCopilotProviderTests: XCTestCase {
    func testFetchUsageDecodesSuggestions() async throws {
        let body = """
        { "used_suggestions": 120, "total_suggestions": 300 }
        """.data(using: .utf8)!

        let stub = StubHTTPClient(outcome: .response(status: 200, body: body))
        let provider = GitHubCopilotProvider(accessToken: "gho_abc", client: stub)

        let usage = try await provider.fetchUsage()
        XCTAssertEqual(usage?.used, 120)
        XCTAssertEqual(usage?.limit, 300)
        XCTAssertEqual(usage?.unit, "suggestions")
        XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer gho_abc")
    }

    func testMissingCredentialThrows() async {
        let provider = GitHubCopilotProvider(accessToken: nil, client: StubHTTPClient(outcome: .response(status: 200, body: Data())))
        do {
            _ = try await provider.fetchUsage()
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCredential)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDescriptorUsesOAuthDeviceFlowSource() {
        let descriptor = GitHubCopilotProvider.descriptor
        guard case .oauthDeviceFlow(let source) = descriptor.credentialSource else {
            XCTFail("expected oauthDeviceFlow credential source")
            return
        }
        XCTAssertEqual(source.clientID, GitHubCopilotProvider.githubOAuthClientID)
        XCTAssertEqual(source.providerName, "GitHub")
        XCTAssertEqual(source.scope, "read:user,copilot")
    }

    func testOAuthDeviceFlowResolverFallsBackToKeychain() {
        let source = OAuthDeviceFlowSource(clientID: "client-id")
        let resolver = CredentialResolverFactory.resolver(
            for: .oauthDeviceFlow(source),
            providerKey: GitHubCopilotProvider.key,
            subscriptionID: UUID()
        )
        XCTAssertEqual(resolver.label, "Mia Keychain: com.likkee.\(GitHubCopilotProvider.key)")
    }
}
