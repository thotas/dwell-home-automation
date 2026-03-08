import XCTest
@testable import DwellCore

final class ModelsTests: XCTestCase {
    func test_deviceSupportsCapability() {
        let device = Device(
            id: "1",
            providerDeviceID: "p1",
            provider: .ring,
            name: "Front Motion",
            type: .motionSensor,
            capabilities: [.motion]
        )

        XCTAssertTrue(device.supports(.motion))
        XCTAssertFalse(device.supports(.switchPower))
    }
}
