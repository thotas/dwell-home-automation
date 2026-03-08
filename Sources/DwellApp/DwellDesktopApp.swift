import DwellCore
import SwiftUI

@main
struct DwellDesktopApp: App {
    @StateObject private var appState = AppState.preview()

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1200, minHeight: 760)
        }
    }
}
