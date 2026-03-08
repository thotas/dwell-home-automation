import DwellCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            ConnectionWizardView()
                .tabItem {
                    Label("Connect", systemImage: "link")
                }

            DashboardView()
                .tabItem {
                    Label("Devices", systemImage: "switch.2")
                }

            RuleBuilderView()
                .tabItem {
                    Label("Automations", systemImage: "bolt.horizontal.circle")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedules", systemImage: "calendar")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text.magnifyingglass")
                }
        }
        .padding(16)
        .onAppear {
            appState.runDueSchedules()
        }
    }
}
