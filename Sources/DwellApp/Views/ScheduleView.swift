import DwellCore
import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedules and Scenes")
                .font(.title2)
                .bold()

            if appState.scenes.isEmpty {
                Text("No scenes available. Connect Govee first and the default Porch scene will appear.")
                    .foregroundStyle(.secondary)
            } else {
                Button("Add Daily Porch Schedule (18:30)") {
                    guard let porchScene = appState.scenes.first else {
                        return
                    }

                    appState.addDailySchedule(
                        name: "Porch Evening",
                        sceneID: porchScene.id,
                        hour: 18,
                        minute: 30,
                        timeZoneID: TimeZone.current.identifier
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Run Due Schedules Now") {
                appState.runDueSchedules()
            }
            .buttonStyle(.bordered)

            List {
                ForEach(appState.schedules) { schedule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.name)
                            .font(.headline)
                        Text(nextRunText(for: schedule))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }

    private func nextRunText(for schedule: Schedule) -> String {
        if let next = schedule.nextRun(after: Date()) {
            return "Next run: \(next.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No next run"
    }
}
