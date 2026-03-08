import Foundation

public final class DeviceControlService {
    private let registry: ProviderRegistry

    public init(registry: ProviderRegistry) {
        self.registry = registry
    }

    @discardableResult
    public func send(_ command: DeviceCommand, to device: Device) throws -> DeviceState {
        let adapter = try registry.adapter(for: device.provider)
        return try adapter.execute(deviceID: device.id, command: command)
    }
}
