import SwiftUI

@main
struct CadenceApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menubar-only app.
        // Settings scene is kept as a placeholder for v2 preferences.
        Settings {
            EmptyView()
        }
    }
}
