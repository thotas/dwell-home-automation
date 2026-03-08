import Foundation

public enum AutomationEvent: Codable, Equatable {
    case motionDetected(deviceID: String)
}

public enum AutomationTrigger: Codable, Equatable {
    case motionDetected(deviceID: String)

    public func matches(event: AutomationEvent) -> Bool {
        switch (self, event) {
        case let (.motionDetected(expectedID), .motionDetected(actualID)):
            return expectedID == actualID
        }
    }
}

public enum AutomationAction: Codable, Equatable {
    case command(deviceID: String, command: DeviceCommand)
}

public struct AutomationRule: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var trigger: AutomationTrigger
    public var actions: [AutomationAction]
    public var isEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        trigger: AutomationTrigger,
        actions: [AutomationAction],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.actions = actions
        self.isEnabled = isEnabled
    }
}

public final class AutomationEngine {
    private var rules: [AutomationRule]
    private let controlService: DeviceControlService
    private let logger: (ExecutionLog) -> Void

    public init(
        rules: [AutomationRule] = [],
        controlService: DeviceControlService,
        logger: @escaping (ExecutionLog) -> Void
    ) {
        self.rules = rules
        self.controlService = controlService
        self.logger = logger
    }

    public func replaceRules(_ newRules: [AutomationRule]) {
        rules = newRules
    }

    public func process(event: AutomationEvent, availableDevices: [Device]) {
        let matchingRules = rules.filter { $0.isEnabled && $0.trigger.matches(event: event) }
        let deviceMap = Dictionary(uniqueKeysWithValues: availableDevices.map { ($0.id, $0) })

        guard !matchingRules.isEmpty else {
            logger(ExecutionLog(source: "Automation", status: .failed, message: "No rules matched event \(event)."))
            return
        }

        for rule in matchingRules {
            for action in rule.actions {
                switch action {
                case let .command(deviceID, command):
                    guard let device = deviceMap[deviceID] else {
                        logger(ExecutionLog(source: rule.name, status: .failed, message: "Missing device \(deviceID)."))
                        continue
                    }

                    do {
                        _ = try controlService.send(command, to: device)
                        logger(ExecutionLog(source: rule.name, status: .success, message: "Executed \(command) on \(device.name)."))
                    } catch {
                        logger(ExecutionLog(source: rule.name, status: .failed, message: error.localizedDescription))
                    }
                }
            }
        }
    }
}

public enum RuleBuilder {
    public static func makeRingToGoveeRule(triggerID: String, actionID: String) -> AutomationRule {
        AutomationRule(
            name: "Ring Motion -> Govee Switch",
            trigger: .motionDetected(deviceID: triggerID),
            actions: [
                .command(deviceID: actionID, command: .switchOn)
            ],
            isEnabled: true
        )
    }
}
