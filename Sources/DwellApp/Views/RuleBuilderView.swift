import DwellCore
import SwiftUI

struct RuleBuilderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automation Rules")
                .font(.title2)
                .bold()

            Text("Create cross-platform automations like Ring motion to Govee switch.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Add Ring -> Govee Template") {
                    appState.addRingToGoveeTemplateRule()
                }
                .buttonStyle(.borderedProminent)

                Button("Simulate Ring Motion") {
                    appState.simulateMotionEvent()
                }
                .buttonStyle(.bordered)
            }

            if appState.rules.isEmpty {
                Text("No rules configured.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(appState.rules) { rule in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(rule.name)
                                .font(.headline)
                            Text("Enabled: \(rule.isEnabled ? "Yes" : "No") · Actions: \(rule.actions.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
