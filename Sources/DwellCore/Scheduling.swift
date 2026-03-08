import Foundation

public enum ScheduleRecurrence: Codable, Equatable {
    case once(Date)
    case daily(hour: Int, minute: Int, timeZoneID: String)
    case weekly(weekday: Int, hour: Int, minute: Int, timeZoneID: String)
}

public struct Schedule: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var sceneID: String
    public var recurrence: ScheduleRecurrence
    public var isEnabled: Bool
    public var lastRunAt: Date?

    public init(
        id: String = UUID().uuidString,
        name: String,
        sceneID: String,
        recurrence: ScheduleRecurrence,
        isEnabled: Bool = true,
        lastRunAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sceneID = sceneID
        self.recurrence = recurrence
        self.isEnabled = isEnabled
        self.lastRunAt = lastRunAt
    }

    public static func daily(hour: Int, minute: Int, timeZoneID: String, sceneID: String, name: String = "Daily Schedule") -> Schedule {
        Schedule(name: name, sceneID: sceneID, recurrence: .daily(hour: hour, minute: minute, timeZoneID: timeZoneID))
    }

    public func nextRun(after now: Date) -> Date? {
        guard isEnabled else { return nil }

        switch recurrence {
        case let .once(date):
            return date > now ? date : nil

        case let .daily(hour, minute, timeZoneID):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current

            let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
            var candidateComponents = DateComponents()
            candidateComponents.year = nowComponents.year
            candidateComponents.month = nowComponents.month
            candidateComponents.day = nowComponents.day
            candidateComponents.hour = hour
            candidateComponents.minute = minute
            candidateComponents.second = 0

            guard let todayCandidate = calendar.date(from: candidateComponents) else { return nil }
            if todayCandidate > now {
                return todayCandidate
            }

            return calendar.date(byAdding: .day, value: 1, to: todayCandidate)

        case let .weekly(weekday, hour, minute, timeZoneID):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current

            var nextDate = now
            for _ in 0..<8 {
                guard let candidateDay = calendar.date(byAdding: .day, value: 1, to: nextDate) else { break }
                nextDate = candidateDay

                let day = calendar.component(.weekday, from: candidateDay)
                if day == weekday {
                    let baseComponents = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                    var final = DateComponents()
                    final.year = baseComponents.year
                    final.month = baseComponents.month
                    final.day = baseComponents.day
                    final.hour = hour
                    final.minute = minute
                    final.second = 0
                    return calendar.date(from: final)
                }
            }
            return nil
        }
    }

    public mutating func markExecuted(at date: Date = Date()) {
        lastRunAt = date
    }
}
