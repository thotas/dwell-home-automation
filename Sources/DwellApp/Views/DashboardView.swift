import DwellCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unified Device Dashboard")
                .font(.title2)
                .bold()

            if appState.devices.isEmpty {
                ContentUnavailableView(
                    "No devices yet",
                    systemImage: "switch.2",
                    description: Text("Connect at least one provider from the Connect tab.")
                )
            } else {
                List {
                    ForEach(appState.devices) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text("\(device.provider.displayName) · \(device.type.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if device.supports(.switchPower) {
                                Button(device.state.isOn ? "Turn Off" : "Turn On") {
                                    appState.togglePower(for: device.id)
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("Read-only")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
