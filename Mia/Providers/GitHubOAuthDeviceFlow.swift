import Foundation

/// Performs the GitHub OAuth device flow for clients that need a long-lived
/// access token (e.g. GitHub Copilot). The flow is split into two phases:
///   1. `startDeviceFlow()` returns the user code and verification URL to show
///      in the UI.
///   2. `pollForToken(deviceCode:interval:)` blocks until the user approves
///      the request or the device code expires.
actor GitHubOAuthDeviceFlow {
    struct DeviceCode: Sendable {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let interval: TimeInterval
        let expiresIn: TimeInterval
    }

    struct Token: Sendable {
        let accessToken: String
        let refreshToken: String?
        let tokenType: String
    }

    private let clientID: String
    private let baseURL: URL
    private let client: HTTPClient

    init(
        clientID: String,
        baseURL: URL = ProviderHTTP.hardcodedURL("https://github.com"),
        client: HTTPClient = URLSessionHTTPClient()
    ) {
        self.clientID = clientID
        self.baseURL = baseURL
        self.client = client
    }

    func startDeviceFlow() async throws -> DeviceCode {
        var request = URLRequest(url: baseURL.appendingPathComponent("/login/device/code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        request.httpBody = "client_id=\(clientID)&scope=read:user,copilot".data(using: .utf8)

        let (data, response) = try await client.data(for: request)
        try ProviderHTTP.validate(response: response)

        guard let params = urlEncodedParams(from: data) else {
            throw ProviderError.decoding("Invalid device code response")
        }

        guard let deviceCode = params["device_code"],
              let userCode = params["user_code"],
              let uriString = params["verification_uri"],
              let verificationURI = URL(string: uriString),
              let interval = params["interval"].flatMap(Double.init),
              let expiresIn = params["expires_in"].flatMap(Double.init) else {
            throw ProviderError.decoding("Incomplete device code response")
        }

        return DeviceCode(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURI: verificationURI,
            interval: interval,
            expiresIn: expiresIn
        )
    }

    func pollForToken(deviceCode: String, interval: TimeInterval) async throws -> Token {
        let start = Date()
        let deadline = start.addingTimeInterval(600)

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            var request = URLRequest(url: baseURL.appendingPathComponent("/login/oauth/access_token"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
            request.httpBody = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)

            let (data, response) = try await client.data(for: request)
            try ProviderHTTP.validate(response: response)

            guard let params = urlEncodedParams(from: data) else {
                throw ProviderError.decoding("Invalid token response")
            }

            if let error = params["error"] {
                if error == "authorization_pending" {
                    continue
                } else if error == "slow_down" {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    continue
                } else {
                    throw ProviderError.other("GitHub OAuth error: \(error)")
                }
            }

            guard let accessToken = params["access_token"] else {
                throw ProviderError.decoding("Missing access token")
            }

            return Token(
                accessToken: accessToken,
                refreshToken: params["refresh_token"],
                tokenType: params["token_type"] ?? "bearer"
            )
        }

        throw ProviderError.timeout
    }

    private func urlEncodedParams(from data: Data) -> [String: String]? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        var params: [String: String] = [:]
        for pair in string.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            params[key] = value
        }
        return params
    }
}
