import XCTest
@testable import DwellCore

final class DeviceControlServiceTests: XCTestCase {
    func test_controlRoutesCommandToMatchingProvider() throws {
        let fake = FakeAdapter(provider: .govee)
        let registry = ProviderRegistry(adapters: [fake])
        let service = DeviceControlService(registry: registry)

        try fake.connect()

        let device = Device(
            id: "govee.1",
            providerDeviceID: "g1",
            provider: .govee,
            name: "Porch Switch",
            type: .switchDevice,
            capabilities: [.switchPower]
        )

        _ = try service.send(.switchOn, to: device)
        XCTAssertEqual(fake.executedCommands.count, 1)
        XCTAssertEqual(fake.executedCommands.first?.command, .switchOn)
    }
}

private final class FakeAdapter: ProviderAdapter {
    let provider: Provider
    private(set) var connectionStatus: ConnectionStatus = .disconnected
    private(set) var executedCommands: [ExecutedCommand] = []

    init(provider: Provider) {
        self.provider = provider
    }

    func connect() throws {
        connectionStatus = .connected
    }

    func disconnect() {
        connectionStatus = .disconnected
    }

    func discoverDevices() throws -> [Device] {
        []
    }

    func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
        executedCommands.append(ExecutedCommand(deviceID: deviceID, command: command))
        return DeviceState(isOn: command == .switchOn)
    }
}
