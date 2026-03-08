import DwellCore
import SwiftUI

struct ConnectionWizardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Wizard")
                .font(.title)
                .bold()

            Text("Connect your home systems in a few clicks. Select a provider and authorize it.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(Provider.allCases) { provider in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(provider.displayName)
                                .font(.headline)
                            Spacer()
                            StatusBadge(status: appState.connectionStatus[provider] ?? .disconnected)
                        }

                        Text("Secure OAuth-style connector with capability discovery.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Connect") {
                                do {
                                    try appState.connect(provider: provider)
                                    appState.createDefaultSceneIfNeeded()
                                    lastError = nil
                                } catch {
                                    lastError = error.localizedDescription
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Disconnect") {
                                appState.disconnect(provider: provider)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let lastError {
                Text("Last connector error: \(lastError)")
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Connected providers: \(appState.connectedProvidersCount()) / \(Provider.allCases.count)")
                    .font(.headline)
                Spacer()
            }
        }
    }
}

private struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}
