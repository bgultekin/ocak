import SwiftUI

@main
struct OcakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — panels are managed by AppDelegate
        Settings {
            EmptyView()
        }
    }
}
