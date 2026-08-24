import Foundation

/// Sendable abstraction over the small subset of `FileManager` operations
/// used by credential resolvers. Eliminates the Swift 6 Sendable warning
/// while keeping the resolvers testable without a real `FileManager`.
struct FileManagerAccess: Sendable {
    let fileExists: @Sendable (String) -> Bool
    let contentsOfDirectory: @Sendable (String) throws -> [String]
    let contents: @Sendable (String) -> Data?

    static let `default` = FileManagerAccess(
        fileExists: { FileManager.default.fileExists(atPath: $0) },
        contentsOfDirectory: { try FileManager.default.contentsOfDirectory(atPath: $0) },
        contents: { FileManager.default.contents(atPath: $0) }
    )
}
