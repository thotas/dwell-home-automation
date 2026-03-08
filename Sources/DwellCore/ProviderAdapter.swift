import Foundation

public enum ProviderError: Error, LocalizedError {
    case notConnected(Provider)
    case adapterMissing(Provider)
    case deviceMissing(String)
    case unsupportedCommand(String)

    public var errorDescription: String? {
        switch self {
        case let .notConnected(provider):
            return "\(provider.displayName) is not connected."
        case let .adapterMissing(provider):
            return "Adapter missing for \(provider.displayName)."
        case let .deviceMissing(deviceID):
            return "Device not found: \(deviceID)."
        case let .unsupportedCommand(reason):
            return "Unsupported command: \(reason)."
        }
    }
}

public protocol ProviderAdapter: AnyObject {
    var provider: Provider { get }
    var connectionStatus: ConnectionStatus { get }

    func connect() throws
    func disconnect()
    func discoverDevices() throws -> [Device]
    func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState
}

public final class ProviderRegistry {
    private var adaptersByProvider: [Provider: ProviderAdapter]

    public init(adapters: [ProviderAdapter]) {
        var dictionary: [Provider: ProviderAdapter] = [:]
        for adapter in adapters {
            dictionary[adapter.provider] = adapter
        }
        self.adaptersByProvider = dictionary
    }

    public var availableProviders: [Provider] {
        Provider.allCases.filter { adaptersByProvider[$0] != nil }
    }

    public func adapter(for provider: Provider) throws -> ProviderAdapter {
        guard let adapter = adaptersByProvider[provider] else {
            throw ProviderError.adapterMissing(provider)
        }
        return adapter
    }
}
