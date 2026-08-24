import Foundation

/// Resolves a credential by reading a known local file.
///
/// Supports JSON key-path extraction and plain text files. Environment
/// overrides (e.g. `CODEX_HOME`) are resolved first, then `~` is expanded.
struct LocalFileResolver: CredentialResolver {
    let source: LocalFileSource
    let fileAccess: FileManagerAccess
    let environment: [String: String]

    var label: String {
        "Local file: \(resolvedPath)"
    }

    init(
        source: LocalFileSource,
        fileAccess: FileManagerAccess = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.source = source
        self.fileAccess = fileAccess
        self.environment = environment
    }

    func resolve() async throws -> ResolvedCredential? {
        let path = resolvedPath
        guard fileAccess.fileExists(path) else {
            throw CredentialResolutionError.fileNotFound(path)
        }
        guard let data = fileAccess.contents(path) else {
            throw CredentialResolutionError.fileUnreadable(path)
        }

        // Plain text: return the whole file as the credential.
        if source.keyPath.isEmpty {
            guard let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            return ResolvedCredential(value: value)
        }

        // JSON key-path extraction.
        let json = try JSONSerialization.jsonObject(with: data)
        guard let value = value(at: source.keyPath, in: json) as? String else {
            throw CredentialResolutionError.keyNotFound(source.keyPath.joined(separator: "."))
        }
        return ResolvedCredential(value: value)
    }

    private var resolvedPath: String {
        var path = source.path
        if let override = source.environmentOverride,
           let envPath = environment[override] {
            path = envPath
        }
        return path.expandingTilde(environment: environment)
    }

    private func value(at keyPath: [String], in json: Any) -> Any? {
        var current: Any? = json
        for key in keyPath {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else {
                return nil
            }
        }
        return current
    }
}

extension String {
    /// Expands a leading `~` to the current user's home directory.
    func expandingTilde(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        guard hasPrefix("~") else { return self }
        let home = environment["HOME"] ?? NSHomeDirectory()
        return home + dropFirst()
    }
}
