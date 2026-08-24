import Foundation

/// Reads usage snapshots from local files (JSON, SQLite, XML) so providers can
/// surface quota without requiring a network call. Each reader returns a
/// `UsageInfo` or throws `ProviderError`.
enum LocalUsageReader {
    /// Reads a JSON file and extracts `used`/`limit` integers at the given
    /// key path. Throws `ProviderError` for missing or malformed data.
    static func readJSON(
        path: String,
        usedKeyPath: [String],
        limitKeyPath: [String],
        unit: String,
        capturedAt: Date
    ) throws -> UsageInfo {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProviderError.network("Cannot read local file: \(path)")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ProviderError.decoding("Malformed JSON at \(path)")
        }

        guard let usedValue = value(at: usedKeyPath, in: object) as? NSNumber else {
            throw ProviderError.decoding("Missing used value at \(usedKeyPath.joined(separator: "."))")
        }
        let used = usedValue.doubleValue

        let limit: Double?
        if let limitValue = value(at: limitKeyPath, in: object) as? NSNumber {
            limit = limitValue.doubleValue
        } else {
            limit = nil
        }

        return UsageInfo(
            used: used,
            limit: limit,
            unit: unit,
            capturedAt: capturedAt,
            rawJSON: String(data: data, encoding: .utf8)
        )
    }

    private static func value(at keyPath: [String], in object: Any) -> Any? {
        var current: Any? = object
        for key in keyPath {
            current = (current as? [String: Any])?[key]
        }
        return current
    }
}
