import CryptoKit
import Foundation

/// Calls AWS Bedrock's CloudWatch usage endpoint with a user-provided access
/// key, secret key, and region formatted as `accessKey:secretKey`.
///
/// CodexBar strategy: AWS credentials from `~/.aws/credentials` or config.
struct AWSBedrockProvider: RegisterableProvider {
    static let key = "awsbedrock"
    static let displayName = "AWS Bedrock"

    let requiresCredential = true

    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            key: key,
            displayName: displayName,
            requiresCredential: true,
            credentialSource: .manual,
            factory: { credential in
                AWSBedrockProvider(credentials: credential?.value ?? "")
            }
        )
    }

    private let credentials: String
    private let region: String
    private let service: String
    private let client: HTTPClient
    private let now: @Sendable () -> Date
    private let dateProvider: @Sendable () -> Date

    init(
        credentials: String,
        region: String = "us-east-1",
        service: String = "bedrock",
        client: HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { .now },
        dateProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.credentials = credentials
        self.region = region
        self.service = service
        self.client = client
        self.now = now
        self.dateProvider = dateProvider
    }

    func fetchPlan() async throws -> PlanInfo? {
        nil
    }

    func fetchUsage() async throws -> UsageInfo? {
        let (accessKey, secretKey) = try parseCredentials()

        let url = ProviderHTTP.hardcodedURL("https://\(service).\(region).amazonaws.com/monitoring")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let signed = AWSV4Signer.sign(
            request: request,
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            service: service,
            date: dateProvider()
        )

        let (data, response) = try await client.data(for: signed)
        try ProviderHTTP.validate(response: response)

        return UsageInfo(
            used: 0,
            limit: nil,
            unit: "USD",
            capturedAt: now(),
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private func parseCredentials() throws -> (accessKey: String, secretKey: String) {
        let parts = credentials.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw ProviderError.invalidCredential
        }
        return (parts[0], parts[1])
    }
}

// MARK: - AWS SigV4 signer

private enum AWSV4Signer {
    static func sign(
        request: URLRequest,
        accessKey: String,
        secretKey: String,
        region: String,
        service: String,
        date: Date
    ) -> URLRequest {
        var request = request

        let dateStamp = format(date: date, format: "yyyyMMdd")
        let amzDate = format(date: date, format: "yyyyMMdd'T'HHmmss'Z'")

        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        if let host = request.url?.host {
            request.setValue(host, forHTTPHeaderField: "Host")
        }

        let payloadHash = sha256(request.httpBody ?? Data())

        let signedHeaderNames = ["host", "x-amz-date"].sorted()
        let signedHeaders = signedHeaderNames.joined(separator: ";")
        let canonicalHeaders = signedHeaderNames
            .map { "\($0):\(request.value(forHTTPHeaderField: $0) ?? "")\n" }
            .joined()

        let canonicalRequest = [
            request.httpMethod ?? "GET",
            request.url?.path ?? "/",
            request.url?.query ?? "",
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            sha256(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")

        let signingKey = signatureKey(secretKey: secretKey, dateStamp: dateStamp, region: region, service: service)
        let signature = hmacSHA256(key: signingKey, data: stringToSign).hexDigest

        let authHeader = "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return request
    }

    private static func format(date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func signatureKey(secretKey: String, dateStamp: String, region: String, service: String) -> SymmetricKey {
        let kSecret = SymmetricKey(data: Data("AWS4\(secretKey)".utf8))
        let kDate = HMAC<SHA256>.authenticationCode(for: Data(dateStamp.utf8), using: kSecret)
        let kRegion = HMAC<SHA256>.authenticationCode(for: Data(region.utf8), using: SymmetricKey(data: Data(kDate)))
        let kService = HMAC<SHA256>.authenticationCode(for: Data(service.utf8), using: SymmetricKey(data: Data(kRegion)))
        let kSigning = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: SymmetricKey(data: Data(kService)))
        return SymmetricKey(data: Data(kSigning))
    }

    private static func hmacSHA256(key: SymmetricKey, data: String) -> Data {
        let code = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)
        return Data(code)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    var hexDigest: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
