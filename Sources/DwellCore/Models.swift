import Foundation

public enum Provider: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleHome
    case googleNest
    case alexa
    case govee
    case ring
    case wyze

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleHome: return "Apple Home"
        case .googleNest: return "Google Nest"
        case .alexa: return "Alexa"
        case .govee: return "Govee"
        case .ring: return "Ring"
        case .wyze: return "Wyze"
        }
    }
}

public enum ConnectionStatus: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

public enum DeviceType: String, Codable, Sendable {
    case light
    case switchDevice
    case motionSensor
    case camera
    case thermostat
    case lock
    case other
}

public enum Capability: String, Codable, Hashable, CaseIterable, Sendable {
    case switchPower
    case brightness
    case motion
    case temperature
    case lock
    case arm
}

public enum DeviceCommand: Codable, Equatable, Sendable {
    case switchOn
    case switchOff
    case setBrightness(Double)
    case arm(Bool)
    case lock(Bool)
}

public struct DeviceState: Codable, Equatable, Sendable {
    public var isOn: Bool
    public var brightness: Double?
    public var motionDetected: Bool
    public var temperature: Double?
    public var armed: Bool
    public var locked: Bool

    public init(
        isOn: Bool = false,
        brightness: Double? = nil,
        motionDetected: Bool = false,
        temperature: Double? = nil,
        armed: Bool = false,
        locked: Bool = false
    ) {
        self.isOn = isOn
        self.brightness = brightness
        self.motionDetected = motionDetected
        self.temperature = temperature
        self.armed = armed
        self.locked = locked
    }
}

public struct Device: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let providerDeviceID: String
    public let provider: Provider
    public var name: String
    public var type: DeviceType
    public var capabilities: Set<Capability>
    public var state: DeviceState
    public var isOnline: Bool
    public var room: String?

    public init(
        id: String,
        providerDeviceID: String,
        provider: Provider,
        name: String,
        type: DeviceType,
        capabilities: Set<Capability>,
        state: DeviceState = DeviceState(),
        isOnline: Bool = true,
        room: String? = nil
    ) {
        self.id = id
        self.providerDeviceID = providerDeviceID
        self.provider = provider
        self.name = name
        self.type = type
        self.capabilities = capabilities
        self.state = state
        self.isOnline = isOnline
        self.room = room
    }

    public func supports(_ capability: Capability) -> Bool {
        capabilities.contains(capability)
    }
}

public enum ExecutionStatus: String, Codable, Sendable {
    case success
    case failed
}

public struct ExecutionLog: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let source: String
    public let status: ExecutionStatus
    public let message: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        source: String,
        status: ExecutionStatus,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.status = status
        self.message = message
        self.timestamp = timestamp
    }
}
