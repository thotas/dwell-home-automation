import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var connectionStatus: [Provider: ConnectionStatus] = [:]
    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var groups: [DeviceGroup] = []
    @Published public private(set) var scenes: [Scene] = []
    @Published public private(set) var rules: [AutomationRule] = []
    @Published public private(set) var schedules: [Schedule] = []
    @Published public private(set) var executionLogs: [ExecutionLog] = []
    @Published public private(set) var providerCredentials: [Provider: ProviderCredentials] = [:]

    private let registry: ProviderRegistry
    private let controlService: DeviceControlService
    private let credentialsStore: CredentialsStore?

    private lazy var automationEngine: AutomationEngine = {
        AutomationEngine(controlService: controlService) { [weak self] log in
            self?.executionLogs.insert(log, at: 0)
        }
    }()

    public init(
        registry: ProviderRegistry = .liveDefault(),
        credentialsStore: CredentialsStore? = try? CredentialsStore.defaultStore()
    ) {
        self.registry = registry
        self.controlService = DeviceControlService(registry: registry)
        self.credentialsStore = credentialsStore
        self.providerCredentials = credentialsStore?.loadAll() ?? [:]

        for provider in registry.availableProviders {
            connectionStatus[provider] = .disconnected
            if providerCredentials[provider] == nil {
                providerCredentials[provider] = ProviderCredentials()
            }
        }
    }

    public static func preview() -> AppState {
        AppState(registry: .mockDefault(), credentialsStore: nil)
    }

    public func credentials(for provider: Provider) -> ProviderCredentials {
        providerCredentials[provider] ?? ProviderCredentials()
    }

    public func updateCredentials(provider: Provider, credentials: ProviderCredentials) {
        providerCredentials[provider] = credentials
        persistCredentials()
        appendLog(source: provider.displayName, status: .success, message: "Credentials saved.")
    }

    public func requiredCredentialFields(for provider: Provider) -> [CredentialFieldDefinition] {
        guard let adapter = try? registry.adapter(for: provider) else {
            return []
        }

        return (adapter as? CredentialAwareProviderAdapter)?.requiredCredentialFields ?? []
    }

    public func connectionHelpText(for provider: Provider) -> String {
        guard let adapter = try? registry.adapter(for: provider) else {
            return ""
        }

        return (adapter as? CredentialAwareProviderAdapter)?.connectionHelpText ?? ""
    }

    public func connect(provider: Provider) throws {
        connectionStatus[provider] = .connecting
        let adapter = try registry.adapter(for: provider)

        if let credentialAware = adapter as? CredentialAwareProviderAdapter {
            credentialAware.updateCredentials(credentials(for: provider))
        }

        do {
            try adapter.connect()
            let discovered = try adapter.discoverDevices()
            mergeDevices(discovered)
            connectionStatus[provider] = .connected
            appendLog(source: provider.displayName, status: .success, message: "Connected and discovered \(discovered.count) devices.")
        } catch {
            connectionStatus[provider] = .error
            appendLog(source: provider.displayName, status: .failed, message: error.localizedDescription)
            throw error
        }
    }

    public func disconnect(provider: Provider) {
        guard let adapter = try? registry.adapter(for: provider) else {
            return
        }

        adapter.disconnect()
        connectionStatus[provider] = .disconnected
        devices.removeAll { $0.provider == provider }
        appendLog(source: provider.displayName, status: .success, message: "Disconnected.")
    }

    public func togglePower(for deviceID: String) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else {
            return
        }

        let device = devices[index]
        let command: DeviceCommand = device.state.isOn ? .switchOff : .switchOn

        do {
            let updatedState = try controlService.send(command, to: device)
            devices[index].state = updatedState
            appendLog(source: device.name, status: .success, message: "Command \(command) executed.")
        } catch {
            appendLog(source: device.name, status: .failed, message: error.localizedDescription)
        }
    }

    public func createGroup(name: String, deviceIDs: [String]) {
        groups.append(DeviceGroup(name: name, deviceIDs: deviceIDs))
    }

    public func createScene(name: String, actions: [SceneAction]) {
        scenes.append(Scene(name: name, actions: actions))
    }

    public func addDailySchedule(name: String, sceneID: String, hour: Int, minute: Int, timeZoneID: String) {
        schedules.append(.daily(hour: hour, minute: minute, timeZoneID: timeZoneID, sceneID: sceneID, name: name))
    }

    public func addRule(_ rule: AutomationRule) {
        rules.append(rule)
        automationEngine.replaceRules(rules)
    }

    public func addRingToGoveeTemplateRule() {
        let ringMotion = devices.first { $0.provider == .ring && $0.supports(.motion) }
        let goveeSwitch = devices.first { $0.provider == .govee && $0.supports(.switchPower) }

        guard let triggerDevice = ringMotion, let actionDevice = goveeSwitch else {
            appendLog(source: "Rules", status: .failed, message: "Connect Ring and Govee devices before adding template rule.")
            return
        }

        let rule = RuleBuilder.makeRingToGoveeRule(triggerID: triggerDevice.id, actionID: actionDevice.id)
        addRule(rule)
        appendLog(source: "Rules", status: .success, message: "Template rule added.")
    }

    public func simulateMotionEvent(deviceID: String = "") {
        automationEngine.replaceRules(rules)
        let targetDeviceID = deviceID.isEmpty ? (devices.first { $0.provider == .ring && $0.supports(.motion) }?.id ?? "ring.motion.front") : deviceID
        automationEngine.process(event: .motionDetected(deviceID: targetDeviceID), availableDevices: devices)
        refreshAllConnectedDevices()
    }

    public func runDueSchedules(now: Date = Date()) {
        for scheduleIndex in schedules.indices {
            guard let nextRun = schedules[scheduleIndex].nextRun(after: now.addingTimeInterval(-1)) else {
                continue
            }

            if abs(nextRun.timeIntervalSince(now)) <= 60 {
                executeScene(sceneID: schedules[scheduleIndex].sceneID)
                schedules[scheduleIndex].markExecuted(at: now)
                appendLog(source: schedules[scheduleIndex].name, status: .success, message: "Schedule executed.")
            }
        }
    }

    public func createDefaultSceneIfNeeded() {
        guard scenes.isEmpty else { return }

        if let govee = devices.first(where: { $0.provider == .govee && $0.supports(.switchPower) }) {
            createScene(
                name: "Porch On",
                actions: [SceneAction(deviceID: govee.id, command: .switchOn)]
            )
        }
    }

    public func connectedProvidersCount() -> Int {
        connectionStatus.values.filter { $0 == .connected }.count
    }

    private func mergeDevices(_ discovered: [Device]) {
        for device in discovered {
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = device
            } else {
                devices.append(device)
            }
        }
    }

    private func appendLog(source: String, status: ExecutionStatus, message: String) {
        executionLogs.insert(ExecutionLog(source: source, status: status, message: message), at: 0)
        if executionLogs.count > 200 {
            executionLogs.removeLast(executionLogs.count - 200)
        }
    }

    private func executeScene(sceneID: String) {
        guard let scene = scenes.first(where: { $0.id == sceneID }) else {
            appendLog(source: "Scene", status: .failed, message: "Scene not found: \(sceneID)")
            return
        }

        for action in scene.actions {
            guard let deviceIndex = devices.firstIndex(where: { $0.id == action.deviceID }) else {
                continue
            }

            do {
                let updatedState = try controlService.send(action.command, to: devices[deviceIndex])
                devices[deviceIndex].state = updatedState
            } catch {
                appendLog(source: scene.name, status: .failed, message: error.localizedDescription)
            }
        }
    }

    private func refreshAllConnectedDevices() {
        for provider in Provider.allCases {
            guard connectionStatus[provider] == .connected else { continue }
            guard let adapter = try? registry.adapter(for: provider) else { continue }
            if let credentialAware = adapter as? CredentialAwareProviderAdapter {
                credentialAware.updateCredentials(credentials(for: provider))
            }
            if let discovered = try? adapter.discoverDevices() {
                mergeDevices(discovered)
            }
        }
    }

    private func persistCredentials() {
        do {
            try credentialsStore?.saveAll(providerCredentials)
        } catch {
            appendLog(source: "Credentials", status: .failed, message: "Failed to save credentials: \(error.localizedDescription)")
        }
    }
}
