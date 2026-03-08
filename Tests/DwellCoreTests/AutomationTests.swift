import XCTest
@testable import DwellCore

final class AutomationTests: XCTestCase {
    func test_ringMotionTriggersGoveeSwitchAction() throws {
        let ring = MockProviderAdapter(provider: .ring, devices: [
            Device(
                id: "ring.motion.front",
                providerDeviceID: "r1",
                provider: .ring,
                name: "Ring Front Motion",
                type: .motionSensor,
                capabilities: [.motion]
            )
        ])

        let govee = MockProviderAdapter(provider: .govee, devices: [
            Device(
                id: "govee.switch.porch",
                providerDeviceID: "g1",
                provider: .govee,
                name: "Govee Porch Switch",
                type: .switchDevice,
                capabilities: [.switchPower]
            )
        ])

        try ring.connect()
        try govee.connect()

        let registry = ProviderRegistry(adapters: [ring, govee])
        let control = DeviceControlService(registry: registry)

        var logs: [ExecutionLog] = []
        let engine = AutomationEngine(controlService: control) { log in
            logs.append(log)
        }

        let rule = RuleBuilder.makeRingToGoveeRule(
            triggerID: "ring.motion.front",
            actionID: "govee.switch.porch"
        )

        engine.replaceRules([rule])

        engine.process(
            event: .motionDetected(deviceID: "ring.motion.front"),
            availableDevices: [
                Device(
                    id: "ring.motion.front",
                    providerDeviceID: "r1",
                    provider: .ring,
                    name: "Ring Front Motion",
                    type: .motionSensor,
                    capabilities: [.motion]
                ),
                Device(
                    id: "govee.switch.porch",
                    providerDeviceID: "g1",
                    provider: .govee,
                    name: "Govee Porch Switch",
                    type: .switchDevice,
                    capabilities: [.switchPower]
                )
            ]
        )

        XCTAssertEqual(govee.commandLog.last?.command, .switchOn)
        XCTAssertEqual(logs.last?.status, .success)
    }

    func test_ruleStoreRoundTrip() throws {
        let store = try RuleStore.temporary()
        let sampleRule = RuleBuilder.makeRingToGoveeRule(
            triggerID: "ring.motion.front",
            actionID: "govee.switch.porch"
        )

        try store.save([sampleRule])
        let loaded = try store.load()

        XCTAssertEqual(loaded, [sampleRule])
    }
}
