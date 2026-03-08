import Foundation

public struct ExecutedCommand: Equatable {
    public let deviceID: String
    public let command: DeviceCommand

    public init(deviceID: String, command: DeviceCommand) {
        self.deviceID = deviceID
        self.command = command
    }
}

public final class MockProviderAdapter: ProviderAdapter {
    public let provider: Provider
    public private(set) var connectionStatus: ConnectionStatus = .disconnected
    public private(set) var commandLog: [ExecutedCommand] = []

    private var devices: [Device]

    public init(provider: Provider, devices: [Device]) {
        self.provider = provider
        self.devices = devices
    }

    public func connect() throws {
        connectionStatus = .connecting
        connectionStatus = .connected
    }

    public func disconnect() {
        connectionStatus = .disconnected
    }

    public func discoverDevices() throws -> [Device] {
        guard connectionStatus == .connected else {
            throw ProviderError.notConnected(provider)
        }
        return devices
    }

    public func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
        guard connectionStatus == .connected else {
            throw ProviderError.notConnected(provider)
        }

        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else {
            throw ProviderError.deviceMissing(deviceID)
        }

        commandLog.append(ExecutedCommand(deviceID: deviceID, command: command))

        switch command {
        case .switchOn:
            devices[index].state.isOn = true
        case .switchOff:
            devices[index].state.isOn = false
        case let .setBrightness(value):
            devices[index].state.brightness = value
            devices[index].state.isOn = value > 0
        case let .arm(value):
            devices[index].state.armed = value
        case let .lock(value):
            devices[index].state.locked = value
        }

        return devices[index].state
    }
}

public extension ProviderRegistry {
    static func mockDefault() -> ProviderRegistry {
        ProviderRegistry(adapters: [
            MockProviderAdapter(provider: .appleHome, devices: Self.sampleDevices(for: .appleHome)),
            MockProviderAdapter(provider: .googleNest, devices: Self.sampleDevices(for: .googleNest)),
            MockProviderAdapter(provider: .alexa, devices: Self.sampleDevices(for: .alexa)),
            MockProviderAdapter(provider: .govee, devices: Self.sampleDevices(for: .govee)),
            MockProviderAdapter(provider: .ring, devices: Self.sampleDevices(for: .ring)),
            MockProviderAdapter(provider: .wyze, devices: Self.sampleDevices(for: .wyze))
        ])
    }

    private static func sampleDevices(for provider: Provider) -> [Device] {
        switch provider {
        case .appleHome:
            return [
                Device(
                    id: "apple.light.living",
                    providerDeviceID: "apple-001",
                    provider: .appleHome,
                    name: "Living Room Light",
                    type: .light,
                    capabilities: [.switchPower, .brightness],
                    state: DeviceState(isOn: false, brightness: 0.7),
                    room: "Living Room"
                )
            ]
        case .googleNest:
            return [
                Device(
                    id: "nest.thermostat.main",
                    providerDeviceID: "nest-001",
                    provider: .googleNest,
                    name: "Main Thermostat",
                    type: .thermostat,
                    capabilities: [.temperature],
                    room: "Hallway"
                )
            ]
        case .alexa:
            return [
                Device(
                    id: "alexa.switch.fan",
                    providerDeviceID: "alexa-001",
                    provider: .alexa,
                    name: "Bedroom Fan Switch",
                    type: .switchDevice,
                    capabilities: [.switchPower],
                    room: "Bedroom"
                )
            ]
        case .govee:
            return [
                Device(
                    id: "govee.switch.porch",
                    providerDeviceID: "govee-001",
                    provider: .govee,
                    name: "Porch Switch",
                    type: .switchDevice,
                    capabilities: [.switchPower],
                    room: "Porch"
                )
            ]
        case .ring:
            return [
                Device(
                    id: "ring.motion.front",
                    providerDeviceID: "ring-001",
                    provider: .ring,
                    name: "Front Door Motion",
                    type: .motionSensor,
                    capabilities: [.motion],
                    room: "Front Door"
                ),
                Device(
                    id: "ring.camera.front",
                    providerDeviceID: "ring-002",
                    provider: .ring,
                    name: "Front Camera",
                    type: .camera,
                    capabilities: [.motion],
                    room: "Front Door"
                )
            ]
        case .wyze:
            return [
                Device(
                    id: "wyze.lock.entry",
                    providerDeviceID: "wyze-001",
                    provider: .wyze,
                    name: "Entry Lock",
                    type: .lock,
                    capabilities: [.lock],
                    room: "Entry"
                )
            ]
        }
    }
}
