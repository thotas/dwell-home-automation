import XCTest
@testable import DwellCore

final class AppStateTests: XCTestCase {
    @MainActor
    func test_connectingProviderMarksConnectionStateConnected() throws {
        let state = AppState.preview()
        try state.connect(provider: .govee)

        XCTAssertEqual(state.connectionStatus[.govee], .connected)
    }

    @MainActor
    func test_ruleBuilderCreatesRingToGoveeRule() {
        let rule = RuleBuilder.makeRingToGoveeRule(
            triggerID: "ring.motion.front",
            actionID: "govee.switch.porch"
        )

        XCTAssertEqual(rule.actions.count, 1)
    }
}
