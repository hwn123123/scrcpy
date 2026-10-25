import SwiftUI

@main
struct ScrcpyStudioApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Scrcpy Studio") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 940, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("刷新设备") {
                    model.refreshDevices()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
