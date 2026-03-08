import XCTest
@testable import DwellCore

final class SchedulingTests: XCTestCase {
    func test_dailyScheduleComputesNextRunInTimeZone() {
        let schedule = Schedule.daily(
            hour: 18,
            minute: 30,
            timeZoneID: "America/Los_Angeles",
            sceneID: "scene-1"
        )

        let now = Date(timeIntervalSince1970: 0)
        let next = schedule.nextRun(after: now)

        XCTAssertNotNil(next)
        XCTAssertTrue((next ?? now) > now)
    }
}
