import SQLite3
import XCTest
@testable import Mia

final class BrowserCookieResolverTests: XCTestCase {
    func testReadsFirefoxCookie() async throws {
        let (home, profileDir) = try makeFakeFirefoxProfile()
        defer { try? FileManager.default.removeItem(at: home) }

        let dbPath = profileDir.appendingPathComponent("cookies.sqlite").path
        try createCookiesSQLite(at: dbPath, name: "session")

        let source = BrowserCookieSource(
            browser: .firefox,
            domains: ["example.com"],
            cookieNames: ["session"]
        )
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home.path
        let resolver = BrowserCookieResolver(source: source, environment: env)
        let credential = try await resolver.resolve()

        XCTAssertEqual(credential?.value, "abc-123")
    }

    func testQuotesInCookieNameAreSafe() async throws {
        let (home, profileDir) = try makeFakeFirefoxProfile()
        defer { try? FileManager.default.removeItem(at: home) }

        let dbPath = profileDir.appendingPathComponent("cookies.sqlite").path
        try createCookiesSQLite(at: dbPath, name: "sess'ion")

        let source = BrowserCookieSource(
            browser: .firefox,
            domains: ["example.com"],
            cookieNames: ["sess'ion"]
        )
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home.path
        let resolver = BrowserCookieResolver(source: source, environment: env)
        let credential = try await resolver.resolve()

        XCTAssertEqual(credential?.value, "abc-123")
    }

    private func makeFakeFirefoxProfile() throws -> (home: URL, profile: URL) {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let profile = home
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")
            .appendingPathComponent("test.default-release")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        return (home, profile)
    }

    private func createCookiesSQLite(at path: String, name: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK, let database = db else {
            throw ProviderError.other("cannot open db")
        }
        defer { sqlite3_close(database) }

        let create = """
        CREATE TABLE moz_cookies (
            id INTEGER PRIMARY KEY,
            name TEXT,
            value TEXT,
            host TEXT,
            lastAccessed INTEGER
        );
        """
        var error: UnsafeMutablePointer<CChar>?
        sqlite3_exec(database, create, nil, nil, &error)
        if let error {
            let message = String(cString: error)
            sqlite3_free(error)
            throw ProviderError.other(message)
        }

        var insert: OpaquePointer?
        let sql = "INSERT INTO moz_cookies (name, value, host, lastAccessed) VALUES (?, ?, ?, ?)"
        guard sqlite3_prepare_v2(database, sql, -1, &insert, nil) == SQLITE_OK, let stmt = insert else {
            throw ProviderError.other("cannot prepare insert")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, "abc-123", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, "www.example.com", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 4, 1)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ProviderError.other("cannot insert cookie")
        }
    }
}
