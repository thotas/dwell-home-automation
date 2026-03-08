import Foundation

public enum PersistenceError: Error {
    case pathUnavailable
}

public final class RuleStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public static func defaultStore() throws -> RuleStore {
        let manager = FileManager.default
        guard let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.pathUnavailable
        }
        let dwellDirectory = appSupport.appendingPathComponent("Dwell", isDirectory: true)
        try manager.createDirectory(at: dwellDirectory, withIntermediateDirectories: true)
        return RuleStore(fileURL: dwellDirectory.appendingPathComponent("rules.json"))
    }

    public static func temporary() throws -> RuleStore {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dwell-rules-\(UUID().uuidString).json")
        return RuleStore(fileURL: tempURL)
    }

    public func save(_ rules: [AutomationRule]) throws {
        let data = try encoder.encode(rules)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() throws -> [AutomationRule] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([AutomationRule].self, from: data)
    }
}
