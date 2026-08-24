@testable import Mia
import XCTest

final class LocalFileResolverTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        super.tearDown()
    }

    func testResolvesPlainTextFile() async throws {
        let file = temporaryDirectory.appendingPathComponent("secret.txt")
        try "my-token".write(to: file, atomically: true, encoding: .utf8)

        let source = LocalFileSource(path: file.path, keyPath: [], environmentOverride: nil)
        let resolver = LocalFileResolver(source: source)

        let credential = try await resolver.resolve()
        XCTAssertEqual(credential?.value, "my-token")
    }

    func testResolvesJSONKeyPath() async throws {
        let file = temporaryDirectory.appendingPathComponent("auth.json")
        let json = "{\"access_token\":\"abc-123\"}"
        try json.write(to: file, atomically: true, encoding: .utf8)

        let source = LocalFileSource(path: file.path, keyPath: ["access_token"], environmentOverride: nil)
        let resolver = LocalFileResolver(source: source)

        let credential = try await resolver.resolve()
        XCTAssertEqual(credential?.value, "abc-123")
    }

    func testThrowsWhenFileMissing() async {
        let source = LocalFileSource(path: temporaryDirectory.appendingPathComponent("missing.json").path, keyPath: [], environmentOverride: nil)
        let resolver = LocalFileResolver(source: source)

        do {
            _ = try await resolver.resolve()
            XCTFail("expected throw")
        } catch let error as CredentialResolutionError {
            if case .fileNotFound = error {} else {
                XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testThrowsWhenJSONKeyMissing() async throws {
        let file = temporaryDirectory.appendingPathComponent("auth.json")
        try "{}".write(to: file, atomically: true, encoding: .utf8)

        let source = LocalFileSource(path: file.path, keyPath: ["access_token"], environmentOverride: nil)
        let resolver = LocalFileResolver(source: source)

        do {
            _ = try await resolver.resolve()
            XCTFail("expected throw")
        } catch let error as CredentialResolutionError {
            if case .keyNotFound = error {} else {
                XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
