import SwiftUI

@main
struct DiacriticsDemoApp: App {
    init() {
        // Headless smoke test for the engine (restore / detect / diff) — used in CI/dev to
        // verify the library wiring without opening a window. `swift run DiacriticsDemo --selftest`.
        if CommandLine.arguments.contains("--selftest") {
            DemoSelfTest.run()
            exit(0)
        }
        // Run as a normal foreground app with a Dock icon + menu bar, even when launched
        // from a plain SwiftPM binary (no .app bundle around it during `swift run`).
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    var body: some Scene {
        WindowGroup("ioDiacritics Demo") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            // Route the standard macOS "About <App>" menu item to our detailed About window
            // instead of the bare system panel.
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }

        // The detailed About, as its own single window — opened from the app menu, the ⓘ
        // button, and the footer link.
        Window("About ioDiacritics Demo", id: AboutView.windowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

/// Menu item that opens the About window (lives in a View so it can read `openWindow`).
private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("About ioDiacritics Demo") { openWindow(id: AboutView.windowID) }
    }
}
