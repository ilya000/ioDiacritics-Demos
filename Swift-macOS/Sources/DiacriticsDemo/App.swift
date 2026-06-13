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
    }
}
