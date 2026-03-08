import DwellCore
import SwiftUI

struct ConnectionWizardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lastError: String?
    @State private var editingProvider: Provider?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Wizard")
                .font(.title)
                .bold()

            Text("Connect your systems using provider APIs or bridge integrations.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                ForEach(Provider.allCases) { provider in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(provider.displayName)
                                .font(.headline)
                            Spacer()
                            StatusBadge(status: appState.connectionStatus[provider] ?? .disconnected)
                        }

                        Text(appState.connectionHelpText(for: provider))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        HStack {
                            Button("Configure") {
                                editingProvider = provider
                            }
                            .buttonStyle(.bordered)

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
        .sheet(item: $editingProvider) { provider in
            CredentialEditorSheet(provider: provider)
                .environmentObject(appState)
        }
    }
}

private struct CredentialEditorSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let provider: Provider
    @State private var credentials: ProviderCredentials

    init(provider: Provider) {
        self.provider = provider
        _credentials = State(initialValue: ProviderCredentials())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure \(provider.displayName)")
                .font(.title3)
                .bold()

            Text(appState.connectionHelpText(for: provider))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let fields = appState.requiredCredentialFields(for: provider)
            if fields.isEmpty {
                Text("No credentials required in-app. Ensure your app is entitled and signed where needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if field.isSecret {
                            SecureField(field.placeholder, text: binding(for: field.id))
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField(field.placeholder, text: binding(for: field.id), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    appState.updateCredentials(provider: provider, credentials: credentials)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .onAppear {
            credentials = appState.credentials(for: provider)
        }
    }

    private func binding(for key: CredentialFieldKey) -> Binding<String> {
        switch key {
        case .accessToken:
            return $credentials.accessToken
        case .apiKey:
            return $credentials.apiKey
        case .projectID:
            return $credentials.projectID
        case .endpointURL:
            return $credentials.endpointURL
        case .bridgeToken:
            return $credentials.bridgeToken
        case .entityFilter:
            return $credentials.entityFilter
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
