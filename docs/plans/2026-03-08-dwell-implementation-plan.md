# Dwell macOS App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a runnable macOS-native, dark-themed Dwell desktop app with multi-provider connection flows, unified device control, grouping, scheduling, and cross-provider automation.

**Architecture:** Implement a layered Swift architecture: SwiftUI presentation layer, domain models/services, and provider adapters behind protocols. Start local-first with mock-capable adapters and deterministic automation runtime (rules + schedules), then integrate persistence and observability.

**Tech Stack:** Swift 6, SwiftUI (macOS), Combine, XCTest, Swift Package Manager, Foundation/OSLog

---

### Task 1: Project Scaffold and Build Baseline

**Files:**
- Create: `Package.swift`
- Create: `Sources/DwellApp/main.swift`
- Create: `Tests/DwellCoreTests/SmokeTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func test_buildPipeline() {
        XCTAssertTrue(true)
    }
}
```

**Step 2: Run test to verify baseline**

Run: `swift test -v`
Expected: FAIL initially because package/targets do not yet exist.

**Step 3: Write minimal implementation**

```swift
import SwiftUI

@main
struct DwellApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Dwell")
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test -v`
Expected: PASS for smoke test.

**Step 5: Commit**

```bash
git add Package.swift Sources/DwellApp/main.swift Tests/DwellCoreTests/SmokeTests.swift
git commit -m "chore: scaffold swift package and baseline tests"
```

### Task 2: Core Domain Models and Capability Mapping

**Files:**
- Create: `Sources/DwellCore/Models.swift`
- Create: `Tests/DwellCoreTests/ModelsTests.swift`

**Step 1: Write the failing test**

```swift
func test_deviceSupportsCapability() {
    let device = Device(id: "1", provider: .ring, name: "Front Motion", type: .motionSensor, capabilities: [.motion])
    XCTAssertTrue(device.supports(.motion))
    XCTAssertFalse(device.supports(.switchPower))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsTests/test_deviceSupportsCapability -v`
Expected: FAIL with unresolved symbols for `Device`/`Capability`.

**Step 3: Write minimal implementation**

```swift
enum Provider: String, CaseIterable, Codable { case appleHome, googleNest, alexa, govee, ring, wyze }
enum DeviceType: String, Codable { case light, switchDevice, motionSensor, camera, thermostat, lock, other }
enum Capability: String, Codable { case switchPower, brightness, motion, temperature, lock, arm }

struct Device: Identifiable, Codable, Equatable {
    let id: String
    let provider: Provider
    var name: String
    var type: DeviceType
    var capabilities: Set<Capability>

    func supports(_ capability: Capability) -> Bool { capabilities.contains(capability) }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter ModelsTests/test_deviceSupportsCapability -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellCore/Models.swift Tests/DwellCoreTests/ModelsTests.swift
git commit -m "feat: add core device and capability domain models"
```

### Task 3: Provider Adapter Protocol + Mock Providers

**Files:**
- Create: `Sources/DwellCore/ProviderAdapter.swift`
- Create: `Sources/DwellCore/MockProviders.swift`
- Create: `Tests/DwellCoreTests/ProviderAdapterTests.swift`

**Step 1: Write the failing test**

```swift
func test_allProvidersAreRegistered() async throws {
    let registry = ProviderRegistry.mockDefault()
    XCTAssertEqual(Set(registry.availableProviders), Set(Provider.allCases))
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ProviderAdapterTests/test_allProvidersAreRegistered -v`
Expected: FAIL because registry/protocol not implemented.

**Step 3: Write minimal implementation**

```swift
protocol ProviderAdapter {
    var provider: Provider { get }
    func connect() async throws
    func discoverDevices() async throws -> [Device]
    func execute(deviceID: String, command: DeviceCommand) async throws
}

struct ProviderRegistry {
    private let adapters: [Provider: ProviderAdapter]
    var availableProviders: [Provider] { Array(adapters.keys).sorted { $0.rawValue < $1.rawValue } }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter ProviderAdapterTests/test_allProvidersAreRegistered -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellCore/ProviderAdapter.swift Sources/DwellCore/MockProviders.swift Tests/DwellCoreTests/ProviderAdapterTests.swift
git commit -m "feat: add provider adapter contract and mock provider registry"
```

### Task 4: Unified Device Control Service

**Files:**
- Create: `Sources/DwellCore/DeviceControlService.swift`
- Create: `Tests/DwellCoreTests/DeviceControlServiceTests.swift`

**Step 1: Write the failing test**

```swift
func test_controlRoutesCommandToMatchingProvider() async throws {
    let harness = try await DeviceControlHarness.make()
    try await harness.service.send(.switchOn, to: harness.device)
    XCTAssertEqual(harness.fake.executedCommands.count, 1)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter DeviceControlServiceTests/test_controlRoutesCommandToMatchingProvider -v`
Expected: FAIL with missing service implementation.

**Step 3: Write minimal implementation**

```swift
final class DeviceControlService {
    private let registry: ProviderRegistry

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    func send(_ command: DeviceCommand, to device: Device) async throws {
        let adapter = try registry.adapter(for: device.provider)
        try await adapter.execute(deviceID: device.id, command: command)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter DeviceControlServiceTests/test_controlRoutesCommandToMatchingProvider -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellCore/DeviceControlService.swift Tests/DwellCoreTests/DeviceControlServiceTests.swift
git commit -m "feat: add unified device control service"
```

### Task 5: Automation Rule Engine (Cross-Provider)

**Files:**
- Create: `Sources/DwellCore/Automation.swift`
- Create: `Tests/DwellCoreTests/AutomationTests.swift`

**Step 1: Write the failing test**

```swift
func test_ringMotionTriggersGoveeSwitchAction() async throws {
    let harness = AutomationHarness.makeRingToGovee()
    try await harness.engine.process(event: .motionDetected(deviceID: harness.triggerDeviceID))
    XCTAssertEqual(harness.commandLog.last?.command, .switchOn)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AutomationTests/test_ringMotionTriggersGoveeSwitchAction -v`
Expected: FAIL because automation engine/rules are missing.

**Step 3: Write minimal implementation**

```swift
struct AutomationRule: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let trigger: AutomationTrigger
    let actions: [AutomationAction]
    var isEnabled: Bool
}

final class AutomationEngine {
    func process(event: AutomationEvent) async throws {
        // evaluate enabled rules and dispatch actions
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter AutomationTests/test_ringMotionTriggersGoveeSwitchAction -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellCore/Automation.swift Tests/DwellCoreTests/AutomationTests.swift
git commit -m "feat: add cross-provider automation engine"
```

### Task 6: Scheduler and Group/Scene Support

**Files:**
- Create: `Sources/DwellCore/Scheduling.swift`
- Create: `Sources/DwellCore/Scenes.swift`
- Create: `Tests/DwellCoreTests/SchedulingTests.swift`

**Step 1: Write the failing test**

```swift
func test_dailyScheduleComputesNextRunInTimeZone() {
    let schedule = Schedule.daily(hour: 18, minute: 30, timeZoneID: "America/Los_Angeles")
    let next = schedule.nextRun(after: Date(timeIntervalSince1970: 0))
    XCTAssertNotNil(next)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter SchedulingTests/test_dailyScheduleComputesNextRunInTimeZone -v`
Expected: FAIL due missing `Schedule` logic.

**Step 3: Write minimal implementation**

```swift
struct DeviceGroup: Identifiable, Codable, Equatable { /* id, name, deviceIDs */ }
struct Scene: Identifiable, Codable, Equatable { /* id, name, actions */ }
struct Schedule: Identifiable, Codable, Equatable {
    func nextRun(after now: Date) -> Date? { /* recurrence calculation */ }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter SchedulingTests/test_dailyScheduleComputesNextRunInTimeZone -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellCore/Scheduling.swift Sources/DwellCore/Scenes.swift Tests/DwellCoreTests/SchedulingTests.swift
git commit -m "feat: add scenes, groups, and scheduler core"
```

### Task 7: App State and Connector Wizard UX

**Files:**
- Create: `Sources/DwellApp/AppState.swift`
- Create: `Sources/DwellApp/Views/ConnectionWizardView.swift`
- Create: `Tests/DwellCoreTests/AppStateTests.swift`

**Step 1: Write the failing test**

```swift
func test_connectingProviderMarksConnectionStateConnected() async throws {
    let state = AppState.preview()
    try await state.connect(provider: .govee)
    XCTAssertEqual(state.connectionStatus[.govee], .connected)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppStateTests/test_connectingProviderMarksConnectionStateConnected -v`
Expected: FAIL due missing `AppState` behavior.

**Step 3: Write minimal implementation**

```swift
@MainActor
final class AppState: ObservableObject {
    @Published var connectionStatus: [Provider: ConnectionStatus]
    func connect(provider: Provider) async throws { /* call adapter + refresh discovery */ }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppStateTests/test_connectingProviderMarksConnectionStateConnected -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellApp/AppState.swift Sources/DwellApp/Views/ConnectionWizardView.swift Tests/DwellCoreTests/AppStateTests.swift
git commit -m "feat: add app state and provider connection wizard"
```

### Task 8: Dashboard, Rule Builder, and Dark Theme UI

**Files:**
- Create: `Sources/DwellApp/Views/DashboardView.swift`
- Create: `Sources/DwellApp/Views/RuleBuilderView.swift`
- Create: `Sources/DwellApp/Views/ScheduleView.swift`
- Modify: `Sources/DwellApp/main.swift`

**Step 1: Write the failing test**

```swift
func test_ruleBuilderCreatesRingToGoveeRule() {
    let state = AppState.preview()
    let rule = RuleBuilder.makeRingToGoveeRule(triggerID: "ring.motion.front", actionID: "govee.switch.porch")
    XCTAssertEqual(rule.actions.count, 1)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppStateTests/test_ruleBuilderCreatesRingToGoveeRule -v`
Expected: FAIL because rule builder helper is missing.

**Step 3: Write minimal implementation**

```swift
struct RuleBuilder {
    static func makeRingToGoveeRule(triggerID: String, actionID: String) -> AutomationRule {
        AutomationRule(/* trigger = motion, action = switch on */)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter AppStateTests/test_ruleBuilderCreatesRingToGoveeRule -v`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/DwellApp/Views/DashboardView.swift Sources/DwellApp/Views/RuleBuilderView.swift Sources/DwellApp/Views/ScheduleView.swift Sources/DwellApp/main.swift
git commit -m "feat: add dark-themed dashboard, rule builder, and scheduling UI"
```

### Task 9: Persistence, Docs, and Final Verification

**Files:**
- Create: `Sources/DwellCore/Persistence.swift`
- Create: `README.md`
- Create: `ARCHITECTURE.md`
- Create: `DECISIONS.md`
- Modify: `Tests/DwellCoreTests/AutomationTests.swift`

**Step 1: Write the failing test**

```swift
func test_ruleStoreRoundTrip() throws {
    let store = try RuleStore.temporary()
    try store.save([sampleRule])
    XCTAssertEqual(try store.load(), [sampleRule])
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AutomationTests/test_ruleStoreRoundTrip -v`
Expected: FAIL because persistence layer does not yet exist.

**Step 3: Write minimal implementation**

```swift
final class RuleStore {
    func save(_ rules: [AutomationRule]) throws { /* JSON encode */ }
    func load() throws -> [AutomationRule] { /* JSON decode */ }
}
```

**Step 4: Run full verification**

Run: `swift test -v && swift build -v`
Expected: PASS for tests and build.

**Step 5: Commit**

```bash
git add Sources/DwellCore/Persistence.swift README.md ARCHITECTURE.md DECISIONS.md Tests/DwellCoreTests/AutomationTests.swift
git commit -m "docs: add architecture and decisions; feat: add persistence"
```

Plan complete and saved to `docs/plans/2026-03-08-dwell-implementation-plan.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch fresh subagent per task, review between tasks, fast iteration

2. Parallel Session (separate) - Open new session with executing-plans, batch execution with checkpoints

Which approach?
