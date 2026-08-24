import Foundation
import SQLite3

/// Resolves a credential by reading a browser cookie.
///
/// Currently supports Firefox cookies (plaintext SQLite). Chrome/Chromium
/// cookies are encrypted with the browser Safe Storage key and require
/// additional keychain access; Safari cookies require Full Disk Access. Both
/// are marked as unavailable for now, so the caller should fall back to a
/// manual cookie header stored in Mia's Keychain.
struct BrowserCookieResolver: CredentialResolver {
    let source: BrowserCookieSource
    let fileAccess: FileManagerAccess
    let environment: [String: String]

    var label: String {
        "Browser cookie: \(source.browser.displayName)"
    }

    init(
        source: BrowserCookieSource,
        fileAccess: FileManagerAccess = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.source = source
        self.fileAccess = fileAccess
        self.environment = environment
    }

    func resolve() async throws -> ResolvedCredential? {
        switch source.browser {
        case .firefox:
            guard let value = try resolveFirefox() else { return nil }
            return ResolvedCredential(value: value)
        case .chrome, .brave, .edge, .arc, .safari:
            throw CredentialResolutionError.cookieStoreUnavailable(source.browser)
        }
    }

    // MARK: - Firefox

    private func resolveFirefox() throws -> String? {
        let profileDir = firefoxProfileDirectory()
        guard let dbPath = profileDir?.appendingPathComponent("cookies.sqlite").path,
              fileAccess.fileExists(dbPath) else {
            throw CredentialResolutionError.fileNotFound("Firefox cookies.sqlite")
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let database = db else {
            throw CredentialResolutionError.fileUnreadable(dbPath)
        }
        defer { sqlite3_close(database) }

        // Build a parameterized query so domains/names cannot inject SQL.
        var parameters: [String] = []
        let domainsClause = source.domains
            .map { domain in
                parameters.append("%\(domain)")
                return "host LIKE ?"
            }
            .joined(separator: " OR ")
        let namesClause = source.requiredNames
            .map { name in
                parameters.append(name)
                return "name = ?"
            }
            .joined(separator: " OR ")
        let sql = "SELECT name, value FROM moz_cookies WHERE (\(domainsClause)) AND (\(namesClause)) ORDER BY lastAccessed DESC LIMIT 1"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else {
            throw CredentialResolutionError.other("Failed to prepare Firefox cookie query")
        }
        defer { sqlite3_finalize(stmt) }

        for (index, value) in parameters.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 1))
        }
        return nil
    }

    private func firefoxProfileDirectory() -> URL? {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let profilesDir = URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")
        guard let entries = try? fileAccess.contentsOfDirectory(profilesDir.path) else {
            return nil
        }
        // Pick the default profile if present, otherwise the first directory.
        let profile = entries.first { $0.hasSuffix(".default-release") }
            ?? entries.first { $0.hasSuffix(".default") }
            ?? entries.first { fileAccess.fileExists(profilesDir.appendingPathComponent($0).path) }
        guard let profile else { return nil }
        return profilesDir.appendingPathComponent(profile)
    }
}
