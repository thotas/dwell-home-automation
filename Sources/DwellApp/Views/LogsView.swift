import DwellCore
import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Execution Logs")
                .font(.title2)
                .bold()

            if appState.executionLogs.isEmpty {
                Text("No log entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(appState.executionLogs) { log in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(log.status == .success ? Color.green : Color.red)
                                .frame(width: 9, height: 9)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.source)
                                    .font(.headline)
                                Text(log.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
