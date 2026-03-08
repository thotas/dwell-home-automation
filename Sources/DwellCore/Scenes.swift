import Foundation

public struct DeviceGroup: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var deviceIDs: [String]

    public init(id: String = UUID().uuidString, name: String, deviceIDs: [String]) {
        self.id = id
        self.name = name
        self.deviceIDs = deviceIDs
    }
}

public struct SceneAction: Codable, Equatable {
    public var deviceID: String
    public var command: DeviceCommand

    public init(deviceID: String, command: DeviceCommand) {
        self.deviceID = deviceID
        self.command = command
    }
}

public struct Scene: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var actions: [SceneAction]

    public init(id: String = UUID().uuidString, name: String, actions: [SceneAction]) {
        self.id = id
        self.name = name
        self.actions = actions
    }
}
