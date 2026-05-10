import SwiftData
import SwiftUI

@main
struct MiaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only app: no visible window scenes. The menu bar item and
        // popover lifecycle are owned by `AppDelegate` / `MenuBarController`.
        Settings {
            EmptyView()
        }
    }
}
