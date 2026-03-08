import Foundation
#if canImport(HomeKit)
import HomeKit
#endif

public enum CredentialFieldKey: String, Sendable {
    case accessToken
    case apiKey
    case projectID
    case endpointURL
    case bridgeToken
    case entityFilter
}

public struct CredentialFieldDefinition: Identifiable, Sendable {
    public let id: CredentialFieldKey
    public let label: String
    public let placeholder: String
    public let isSecret: Bool

    public init(id: CredentialFieldKey, label: String, placeholder: String, isSecret: Bool = false) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.isSecret = isSecret
    }
}

public protocol CredentialAwareProviderAdapter: ProviderAdapter {
    var requiredCredentialFields: [CredentialFieldDefinition] { get }
    var connectionHelpText: String { get }
    func updateCredentials(_ credentials: ProviderCredentials)
}

public extension ProviderRegistry {
    static func liveDefault() -> ProviderRegistry {
        ProviderRegistry(adapters: [
            AppleHomeProviderAdapter(),
            GoogleNestProviderAdapter(),
            GoveeProviderAdapter(),
            HomeAssistantBridgeAdapter(provider: .alexa),
            HomeAssistantBridgeAdapter(provider: .ring),
            HomeAssistantBridgeAdapter(provider: .wyze)
        ])
    }
}

public final class GoogleNestProviderAdapter: CredentialAwareProviderAdapter {
    public let provider: Provider = .googleNest
    public private(set) var connectionStatus: ConnectionStatus = .disconnected
    public let requiredCredentialFields: [CredentialFieldDefinition] = [
        CredentialFieldDefinition(id: .accessToken, label: "Access Token", placeholder: "ya29...", isSecret: true),
        CredentialFieldDefinition(id: .projectID, label: "Project/Enterprise ID", placeholder: "enterprises/PROJECT_ID or PROJECT_ID")
    ]
    public let connectionHelpText: String = "Uses Google Smart Device Management API. Provide OAuth access token and Project/Enterprise ID."

    private let http = HTTPClient()
    private var credentials = ProviderCredentials()
    private var deviceNameByID: [String: String] = [:]

    public init() {}

    public func updateCredentials(_ credentials: ProviderCredentials) {
        self.credentials = credentials
    }

    public func connect() throws {
        _ = try discoverDevices()
        connectionStatus = .connected
    }

    public func disconnect() {
        connectionStatus = .disconnected
    }

    public func discoverDevices() throws -> [Device] {
        let token = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectID = normalizedNestProjectID(credentials.projectID)

        guard !token.isEmpty else {
            throw ProviderError.unsupportedCommand("Missing Google Nest access token")
        }
        guard !projectID.isEmpty else {
            throw ProviderError.unsupportedCommand("Missing Google Nest project/enterprise ID")
        }

        let url = "https://smartdevicemanagement.googleapis.com/v1/\(projectID)/devices"
        let payload = try http.sendJSON(
            method: "GET",
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )

        guard let rawDevices = payload["devices"] as? [[String: Any]] else {
            return []
        }

        var devices: [Device] = []
        for raw in rawDevices {
            guard let fullName = raw["name"] as? String else { continue }
            let shortID = fullName.split(separator: "/").last.map(String.init) ?? UUID().uuidString
            let type = (raw["type"] as? String) ?? ""
            let traits = (raw["traits"] as? [String: Any]) ?? [:]
            let info = (raw["parentRelations"] as? [[String: Any]])?.first
            let displayName = (info?["displayName"] as? String) ?? shortID

            let mappedType: DeviceType
            if type.contains("THERMOSTAT") {
                mappedType = .thermostat
            } else if type.contains("CAMERA") || type.contains("DOORBELL") {
                mappedType = .camera
            } else {
                mappedType = .other
            }

            var capabilities = Set<Capability>()
            if traits["sdm.devices.traits.ThermostatTemperatureSetpoint"] != nil {
                capabilities.insert(.temperature)
            }
            if traits["sdm.devices.traits.ObjectDetection"] != nil {
                capabilities.insert(.motion)
            }

            if capabilities.isEmpty {
                capabilities = [.motion]
            }

            let deviceID = "nest.\(shortID)"
            deviceNameByID[deviceID] = fullName

            devices.append(
                Device(
                    id: deviceID,
                    providerDeviceID: fullName,
                    provider: .googleNest,
                    name: displayName,
                    type: mappedType,
                    capabilities: capabilities,
                    state: DeviceState(),
                    isOnline: true,
                    room: nil
                )
            )
        }

        return devices
    }

    public func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
        guard connectionStatus == .connected else {
            throw ProviderError.notConnected(provider)
        }

        guard let fullName = deviceNameByID[deviceID] else {
            throw ProviderError.deviceMissing(deviceID)
        }

        switch command {
        case let .setBrightness(value):
            let token = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = "https://smartdevicemanagement.googleapis.com/v1/\(fullName):executeCommand"
            _ = try http.send(
                method: "POST",
                url: url,
                headers: ["Authorization": "Bearer \(token)"],
                jsonBody: [
                    "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
                    "params": [
                        "heatCelsius": max(9.0, min(32.0, value))
                    ]
                ]
            )
            return DeviceState(temperature: value)

        default:
            throw ProviderError.unsupportedCommand("Google Nest command not supported for this device or command type")
        }
    }

    private func normalizedNestProjectID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("enterprises/") {
            return trimmed
        }
        return "enterprises/\(trimmed)"
    }
}

public final class GoveeProviderAdapter: CredentialAwareProviderAdapter {
    public let provider: Provider = .govee
    public private(set) var connectionStatus: ConnectionStatus = .disconnected
    public let requiredCredentialFields: [CredentialFieldDefinition] = [
        CredentialFieldDefinition(id: .apiKey, label: "API Key", placeholder: "Govee API key", isSecret: true)
    ]
    public let connectionHelpText: String = "Uses Govee Open API (developer-api.govee.com). Provide your Govee API key."

    private struct GoveeIdentity {
        let mac: String
        let model: String
        let supportCommands: [String]
    }

    private let http = HTTPClient()
    private var credentials = ProviderCredentials()
    private var identitiesByDeviceID: [String: GoveeIdentity] = [:]

    public init() {}

    public func updateCredentials(_ credentials: ProviderCredentials) {
        self.credentials = credentials
    }

    public func connect() throws {
        _ = try discoverDevices()
        connectionStatus = .connected
    }

    public func disconnect() {
        connectionStatus = .disconnected
    }

    public func discoverDevices() throws -> [Device] {
        let key = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw ProviderError.unsupportedCommand("Missing Govee API key")
        }

        let payload = try http.sendJSON(
            method: "GET",
            url: "https://developer-api.govee.com/v1/devices",
            headers: ["Govee-API-Key": key]
        )

        let rawDevices = (payload["data"] as? [String: Any])?["devices"] as? [[String: Any]] ?? []
        var devices: [Device] = []

        for raw in rawDevices {
            let mac = (raw["device"] as? String) ?? ""
            let model = (raw["model"] as? String) ?? ""
            guard !mac.isEmpty, !model.isEmpty else { continue }

            let deviceName = (raw["deviceName"] as? String) ?? mac
            let commands = (raw["supportCmds"] as? [String]) ?? []
            var capabilities = Set<Capability>()

            if commands.contains("turn") {
                capabilities.insert(.switchPower)
            }
            if commands.contains("brightness") {
                capabilities.insert(.brightness)
            }

            let id = "govee.\(mac.replacingOccurrences(of: ":", with: "").lowercased())"
            identitiesByDeviceID[id] = GoveeIdentity(mac: mac, model: model, supportCommands: commands)

            devices.append(
                Device(
                    id: id,
                    providerDeviceID: mac,
                    provider: .govee,
                    name: deviceName,
                    type: .switchDevice,
                    capabilities: capabilities.isEmpty ? [.switchPower] : capabilities,
                    state: DeviceState(),
                    isOnline: true,
                    room: nil
                )
            )
        }

        return devices
    }

    public func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
        guard connectionStatus == .connected else {
            throw ProviderError.notConnected(provider)
        }

        let key = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let identity = identitiesByDeviceID[deviceID] else {
            throw ProviderError.deviceMissing(deviceID)
        }

        let (name, value): (String, Any)
        switch command {
        case .switchOn:
            name = "turn"
            value = "on"
        case .switchOff:
            name = "turn"
            value = "off"
        case let .setBrightness(brightness):
            name = "brightness"
            value = Int(max(0, min(100, brightness)))
        default:
            throw ProviderError.unsupportedCommand("Govee supports turn/brightness in this adapter")
        }

        _ = try http.send(
            method: "PUT",
            url: "https://developer-api.govee.com/v1/devices/control",
            headers: ["Govee-API-Key": key],
            jsonBody: [
                "device": identity.mac,
                "model": identity.model,
                "cmd": [
                    "name": name,
                    "value": value
                ]
            ]
        )

        switch command {
        case .switchOn:
            return DeviceState(isOn: true)
        case .switchOff:
            return DeviceState(isOn: false)
        case let .setBrightness(level):
            return DeviceState(isOn: level > 0, brightness: level)
        default:
            return DeviceState()
        }
    }
}

public final class HomeAssistantBridgeAdapter: CredentialAwareProviderAdapter {
    public let provider: Provider
    public private(set) var connectionStatus: ConnectionStatus = .disconnected

    public let requiredCredentialFields: [CredentialFieldDefinition] = [
        CredentialFieldDefinition(id: .endpointURL, label: "Home Assistant URL", placeholder: "http://homeassistant.local:8123"),
        CredentialFieldDefinition(id: .bridgeToken, label: "Long-lived Access Token", placeholder: "eyJ...", isSecret: true),
        CredentialFieldDefinition(id: .entityFilter, label: "Entity Prefixes (CSV)", placeholder: "binary_sensor.ring,camera.ring")
    ]

    public var connectionHelpText: String {
        "\(provider.displayName) uses Home Assistant bridge mode. Add this integration in Home Assistant, then provide URL/token and entity prefixes."
    }

    private let http = HTTPClient()
    private var credentials = ProviderCredentials()
    private var entityIDByDeviceID: [String: String] = [:]

    public init(provider: Provider) {
        self.provider = provider
    }

    public func updateCredentials(_ credentials: ProviderCredentials) {
        self.credentials = credentials
    }

    public func connect() throws {
        _ = try fetchStates()
        connectionStatus = .connected
    }

    public func disconnect() {
        connectionStatus = .disconnected
    }

    public func discoverDevices() throws -> [Device] {
        let states = try fetchStates()
        let filters = resolvedEntityPrefixes()

        var devices: [Device] = []
        entityIDByDeviceID = [:]

        for state in states {
            guard let entityID = state["entity_id"] as? String else { continue }
            if !filters.isEmpty, !filters.contains(where: { entityID.hasPrefix($0) }) {
                continue
            }

            let split = entityID.split(separator: ".", maxSplits: 1).map(String.init)
            guard let domain = split.first else { continue }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = (attributes?["friendly_name"] as? String) ?? entityID
            let rawState = (state["state"] as? String) ?? ""

            let type = mappedDeviceType(forDomain: domain, entityID: entityID)
            let capabilities = mappedCapabilities(forDomain: domain, entityID: entityID)
            let normalizedState = mappedDeviceState(forDomain: domain, entityID: entityID, rawState: rawState)

            let id = "\(provider.rawValue).\(entityID.replacingOccurrences(of: ".", with: "_"))"
            entityIDByDeviceID[id] = entityID

            devices.append(
                Device(
                    id: id,
                    providerDeviceID: entityID,
                    provider: provider,
                    name: displayName,
                    type: type,
                    capabilities: capabilities,
                    state: normalizedState,
                    isOnline: rawState != "unavailable",
                    room: attributes?["room"] as? String
                )
            )
        }

        return devices
    }

    public func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
        guard connectionStatus == .connected else {
            throw ProviderError.notConnected(provider)
        }

        guard let entityID = entityIDByDeviceID[deviceID] else {
            throw ProviderError.deviceMissing(deviceID)
        }

        let split = entityID.split(separator: ".", maxSplits: 1).map(String.init)
        guard let domain = split.first else {
            throw ProviderError.unsupportedCommand("Invalid entity id")
        }

        let payload: [String: Any] = ["entity_id": entityID]

        switch command {
        case .switchOn:
            try callService(domain: domainForPower(domain), service: "turn_on", payload: payload)
            return DeviceState(isOn: true)
        case .switchOff:
            try callService(domain: domainForPower(domain), service: "turn_off", payload: payload)
            return DeviceState(isOn: false)
        case let .lock(isLocked):
            try callService(domain: "lock", service: isLocked ? "lock" : "unlock", payload: payload)
            return DeviceState(locked: isLocked)
        case let .arm(armed):
            let service = armed ? "alarm_arm_home" : "alarm_disarm"
            try callService(domain: "alarm_control_panel", service: service, payload: payload)
            return DeviceState(armed: armed)
        default:
            throw ProviderError.unsupportedCommand("Unsupported bridge command")
        }
    }

    private func fetchStates() throws -> [[String: Any]] {
        let baseURL = normalizedBaseURL(credentials.endpointURL)
        guard !baseURL.isEmpty else {
            throw ProviderError.unsupportedCommand("Missing Home Assistant URL")
        }
        guard !credentials.bridgeToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.unsupportedCommand("Missing Home Assistant token")
        }

        let response = try http.send(
            method: "GET",
            url: "\(baseURL)/api/states",
            headers: [
                "Authorization": "Bearer \(credentials.bridgeToken)",
                "Content-Type": "application/json"
            ]
        )

        let object = try JSONSerialization.jsonObject(with: response.data)
        return object as? [[String: Any]] ?? []
    }

    private func callService(domain: String, service: String, payload: [String: Any]) throws {
        let baseURL = normalizedBaseURL(credentials.endpointURL)
        _ = try http.send(
            method: "POST",
            url: "\(baseURL)/api/services/\(domain)/\(service)",
            headers: [
                "Authorization": "Bearer \(credentials.bridgeToken)",
                "Content-Type": "application/json"
            ],
            jsonBody: payload
        )
    }

    private func normalizedBaseURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func resolvedEntityPrefixes() -> [String] {
        let custom = credentials.entityFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !custom.isEmpty {
            return custom
        }

        switch provider {
        case .ring:
            return ["binary_sensor.ring", "camera.ring", "alarm_control_panel.ring", "sensor.ring"]
        case .wyze:
            return ["switch.wyze", "lock.wyze", "camera.wyze", "binary_sensor.wyze", "light.wyze"]
        case .alexa:
            return ["media_player.alexa", "switch.alexa", "light.alexa", "sensor.alexa"]
        default:
            return []
        }
    }

    private func mappedDeviceType(forDomain domain: String, entityID: String) -> DeviceType {
        if domain == "light" || domain == "switch" || domain == "fan" { return .switchDevice }
        if domain == "lock" { return .lock }
        if domain == "camera" { return .camera }
        if domain == "binary_sensor" && entityID.contains("motion") { return .motionSensor }
        if domain == "climate" { return .thermostat }
        return .other
    }

    private func mappedCapabilities(forDomain domain: String, entityID: String) -> Set<Capability> {
        var capabilities = Set<Capability>()
        if ["light", "switch", "fan", "input_boolean"].contains(domain) {
            capabilities.insert(.switchPower)
        }
        if domain == "lock" {
            capabilities.insert(.lock)
        }
        if domain == "alarm_control_panel" {
            capabilities.insert(.arm)
        }
        if domain == "binary_sensor", entityID.contains("motion") {
            capabilities.insert(.motion)
        }
        return capabilities
    }

    private func mappedDeviceState(forDomain domain: String, entityID: String, rawState: String) -> DeviceState {
        let lower = rawState.lowercased()
        let isOn = ["on", "open", "home", "playing", "unlocked"].contains(lower)
        let motion = domain == "binary_sensor" && entityID.contains("motion") && lower == "on"
        let locked = domain == "lock" && lower == "locked"
        let armed = domain == "alarm_control_panel" && lower.contains("armed")
        return DeviceState(isOn: isOn, motionDetected: motion, armed: armed, locked: locked)
    }

    private func domainForPower(_ domain: String) -> String {
        if ["switch", "light", "fan", "input_boolean"].contains(domain) {
            return domain
        }
        return "homeassistant"
    }
}

public final class AppleHomeProviderAdapter: CredentialAwareProviderAdapter {
    public let provider: Provider = .appleHome
    public private(set) var connectionStatus: ConnectionStatus = .disconnected
    public let requiredCredentialFields: [CredentialFieldDefinition] = []
    public let connectionHelpText: String = "Uses Apple HomeKit APIs. App must be code signed with HomeKit entitlement and NSHomeKitUsageDescription."

    public init() {}

    public func updateCredentials(_ credentials: ProviderCredentials) {}

    public func connect() throws {
#if canImport(HomeKit)
        _ = try loadHomes()
        connectionStatus = .connected
#else
        throw ProviderError.unsupportedCommand("HomeKit framework not available")
#endif
    }

    public func disconnect() {
        connectionStatus = .disconnected
    }

    public func discoverDevices() throws -> [Device] {
#if canImport(HomeKit)
        let homes = try loadHomes()
        var devices: [Device] = []

        for home in homes {
            for accessory in home.accessories {
                let id = "apple.\(accessory.uniqueIdentifier.uuidString.lowercased())"
                let capabilities = self.capabilities(for: accessory)
                let state = self.state(for: accessory)

                devices.append(
                    Device(
                        id: id,
                        providerDeviceID: accessory.uniqueIdentifier.uuidString,
                        provider: .appleHome,
                        name: accessory.name,
                        type: mappedType(for: accessory),
                        capabilities: capabilities,
                        state: state,
                        isOnline: accessory.isReachable,
                        room: roomName(for: accessory, in: home)
                    )
                )
            }
        }

        return devices
#else
        return []
#endif
    }

    public func execute(deviceID: String, command: DeviceCommand) throws -> DeviceState {
#if canImport(HomeKit)
        let uuidString = deviceID.replacingOccurrences(of: "apple.", with: "")
        guard let targetUUID = UUID(uuidString: uuidString) else {
            throw ProviderError.deviceMissing(deviceID)
        }

        let homes = try loadHomes()
        for home in homes {
            if let accessory = home.accessories.first(where: { $0.uniqueIdentifier == targetUUID }) {
                try apply(command: command, to: accessory)
                return state(for: accessory)
            }
        }

        throw ProviderError.deviceMissing(deviceID)
#else
        throw ProviderError.unsupportedCommand("HomeKit framework not available")
#endif
    }

#if canImport(HomeKit)
    private func loadHomes() throws -> [HMHome] {
        let probe = HomeKitProbe()
        let homes = try probe.waitForHomes()
        return homes
    }

    private func roomName(for accessory: HMAccessory, in home: HMHome) -> String? {
        home.rooms.first(where: { $0.accessories.contains(where: { $0.uniqueIdentifier == accessory.uniqueIdentifier }) })?.name
    }

    private func mappedType(for accessory: HMAccessory) -> DeviceType {
        let serviceTypes = Set(accessory.services.map { $0.serviceType })
        if serviceTypes.contains(HMServiceTypeLightbulb) { return .light }
        if serviceTypes.contains(HMServiceTypeLockMechanism) { return .lock }
        if serviceTypes.contains(HMServiceTypeThermostat) { return .thermostat }
        if serviceTypes.contains(HMServiceTypeSecuritySystem) { return .camera }
        return .other
    }

    private func capabilities(for accessory: HMAccessory) -> Set<Capability> {
        var capabilities = Set<Capability>()

        for service in accessory.services {
            for characteristic in service.characteristics {
                switch characteristic.characteristicType {
                case HMCharacteristicTypePowerState:
                    capabilities.insert(.switchPower)
                case HMCharacteristicTypeBrightness:
                    capabilities.insert(.brightness)
                case HMCharacteristicTypeMotionDetected:
                    capabilities.insert(.motion)
                case HMCharacteristicTypeCurrentTemperature,
                     HMCharacteristicTypeTargetTemperature,
                     HMCharacteristicTypeTemperatureUnits:
                    capabilities.insert(.temperature)
                case HMCharacteristicTypeLockCurrentState,
                     HMCharacteristicTypeLockTargetState:
                    capabilities.insert(.lock)
                default:
                    break
                }
            }
        }

        return capabilities
    }

    private func state(for accessory: HMAccessory) -> DeviceState {
        var state = DeviceState()

        for service in accessory.services {
            for characteristic in service.characteristics {
                guard let value = characteristic.value else { continue }
                switch characteristic.characteristicType {
                case HMCharacteristicTypePowerState:
                    state.isOn = (value as? Bool) ?? false
                case HMCharacteristicTypeBrightness:
                    state.brightness = (value as? NSNumber)?.doubleValue
                case HMCharacteristicTypeMotionDetected:
                    state.motionDetected = (value as? Bool) ?? false
                case HMCharacteristicTypeCurrentTemperature:
                    state.temperature = (value as? NSNumber)?.doubleValue
                case HMCharacteristicTypeLockCurrentState:
                    state.locked = ((value as? NSNumber)?.intValue ?? 1) == HMCharacteristicValueLockMechanismState.secured.rawValue
                default:
                    break
                }
            }
        }

        return state
    }

    private func apply(command: DeviceCommand, to accessory: HMAccessory) throws {
        switch command {
        case .switchOn:
            guard let char = characteristic(ofType: HMCharacteristicTypePowerState, in: accessory) else {
                throw ProviderError.unsupportedCommand("Power state not supported")
            }
            try write(characteristic: char, value: true)
        case .switchOff:
            guard let char = characteristic(ofType: HMCharacteristicTypePowerState, in: accessory) else {
                throw ProviderError.unsupportedCommand("Power state not supported")
            }
            try write(characteristic: char, value: false)
        case let .setBrightness(level):
            guard let char = characteristic(ofType: HMCharacteristicTypeBrightness, in: accessory) else {
                throw ProviderError.unsupportedCommand("Brightness not supported")
            }
            let clamped = max(0, min(100, level))
            try write(characteristic: char, value: NSNumber(value: clamped))
        case let .lock(isLocked):
            guard let char = characteristic(ofType: HMCharacteristicTypeLockTargetState, in: accessory) else {
                throw ProviderError.unsupportedCommand("Lock command not supported")
            }
            let target = isLocked ? HMCharacteristicValueLockMechanismState.secured.rawValue : HMCharacteristicValueLockMechanismState.unsecured.rawValue
            try write(characteristic: char, value: NSNumber(value: target))
        case .arm:
            throw ProviderError.unsupportedCommand("Arm command not mapped for Apple Home in this build")
        }
    }

    private func characteristic(ofType type: String, in accessory: HMAccessory) -> HMCharacteristic? {
        for service in accessory.services {
            if let characteristic = service.characteristics.first(where: { $0.characteristicType == type }) {
                return characteristic
            }
        }
        return nil
    }

    private func write(characteristic: HMCharacteristic, value: Any) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var outputError: Error?

        characteristic.writeValue(value) { error in
            outputError = error
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 10)
        if let outputError {
            throw outputError
        }
    }
#endif
}

#if canImport(HomeKit)
private final class HomeKitProbe: NSObject, HMHomeManagerDelegate {
    private let manager = HMHomeManager()
    private var semaphore = DispatchSemaphore(value: 0)
    private var finished = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func waitForHomes(timeout: TimeInterval = 10) throws -> [HMHome] {
        if manager.homes.isEmpty {
            _ = semaphore.wait(timeout: .now() + timeout)
        }

        return manager.homes
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        guard !finished else { return }
        finished = true
        semaphore.signal()
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        guard !finished else { return }
        finished = true
        semaphore.signal()
    }
}
#endif
