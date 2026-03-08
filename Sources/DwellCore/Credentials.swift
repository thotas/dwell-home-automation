import Foundation

public struct ProviderCredentials: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var apiKey: String
    public var apiID: String
    public var projectID: String
    public var email: String
    public var password: String
    public var endpointURL: String
    public var bridgeToken: String
    public var entityFilter: String

    public init(
        accessToken: String = "",
        refreshToken: String = "",
        apiKey: String = "",
        apiID: String = "",
        projectID: String = "",
        email: String = "",
        password: String = "",
        endpointURL: String = "",
        bridgeToken: String = "",
        entityFilter: String = ""
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.apiKey = apiKey
        self.apiID = apiID
        self.projectID = projectID
        self.email = email
        self.password = password
        self.endpointURL = endpointURL
        self.bridgeToken = bridgeToken
        self.entityFilter = entityFilter
    }

    public var isEmpty: Bool {
        accessToken.isEmpty &&
            refreshToken.isEmpty &&
            apiKey.isEmpty &&
            apiID.isEmpty &&
            projectID.isEmpty &&
            email.isEmpty &&
            password.isEmpty &&
            endpointURL.isEmpty &&
            bridgeToken.isEmpty &&
            entityFilter.isEmpty
    }
}

public final class CredentialsStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public static func defaultStore() throws -> CredentialsStore {
        let manager = FileManager.default
        guard let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.pathUnavailable
        }

        let dwellDirectory = appSupport.appendingPathComponent("Dwell", isDirectory: true)
        try manager.createDirectory(at: dwellDirectory, withIntermediateDirectories: true)
        return CredentialsStore(fileURL: dwellDirectory.appendingPathComponent("provider-credentials.json"))
    }

    public func loadAll() -> [Provider: ProviderCredentials] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try decoder.decode([String: ProviderCredentials].self, from: data)
            var mapped: [Provider: ProviderCredentials] = [:]
            for (key, value) in payload {
                if let provider = Provider(rawValue: key) {
                    mapped[provider] = value
                }
            }
            return mapped
        } catch {
            return [:]
        }
    }

    public func saveAll(_ credentials: [Provider: ProviderCredentials]) throws {
        var payload: [String: ProviderCredentials] = [:]
        for (provider, creds) in credentials {
            payload[provider.rawValue] = creds
        }

        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }
}
