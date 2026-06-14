import AppKit
import InputMethodKit

@objc(IODiacriticsAppDelegate)
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared instance so the input controller can reach the candidate window.
    static private(set) var shared: AppDelegate?

    private var server: IMKServer?
    /// System candidate window (Chinese-IME style), shown when a word has several readings.
    private(set) var candidates: IMKCandidates?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        guard
            let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
            let bundleIdentifier = Bundle.main.bundleIdentifier
        else {
            NSLog("ioDiacritics InputMethod: missing InputMethodConnectionName or bundle id")
            NSApp.terminate(nil)
            return
        }

        let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)
        self.server = server
        // A single shared candidate panel for the whole input method.
        self.candidates = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        NSLog("ioDiacritics InputMethod: server started as %@", connectionName)
    }
}
