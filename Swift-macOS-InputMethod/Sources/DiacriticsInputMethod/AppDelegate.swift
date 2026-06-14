import AppKit
import InputMethodKit

@objc(IODiacriticsAppDelegate)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard
            let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
            let bundleIdentifier = Bundle.main.bundleIdentifier
        else {
            NSLog("ioDiacritics InputMethod: missing InputMethodConnectionName or bundle id")
            NSApp.terminate(nil)
            return
        }

        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
        NSLog("ioDiacritics InputMethod: server started as %@", connectionName)
    }
}

