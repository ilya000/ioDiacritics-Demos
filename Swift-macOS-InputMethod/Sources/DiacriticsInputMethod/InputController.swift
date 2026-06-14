import AppKit
import Foundation
import InputMethodKit
import ioDiacritics
import ioDiacriticsBosnian
import ioDiacriticsCroatian
import ioDiacriticsSerbian

@objc(IODiacriticsInputController)
final class InputController: IMKInputController {
    private var buffer = ""
    private var previousWord: String?

    // Candidate state — Chinese-IME-style readings shown only when a bald word is genuinely
    // ambiguous (the dictionary holds ≥2 accented forms for it). Empty the rest of the time, so
    // ordinary typing is unchanged.
    private var currentCandidates: [String] = []
    private var highlighted: String?

    // Load dictionaries straight from the app bundle via Bundle.main + the public Restorer.load,
    // NOT via makeRestorer/Bundle.module: the SwiftPM resource bundles ship without an Info.plist
    // and Bundle.module can fatalError under LaunchServices / app translocation. Live-keyboard
    // semantics → loadInvariant: false (lighter).
    private static let serbian = loadPack("deshishana_sr", Serbian.profile) { Serbian.makeRestorer(loadInvariant: false) }
    private static let croatian = loadPack("deshishana_hr", Croatian.profile) { Croatian.makeRestorer(loadInvariant: false) }
    private static let bosnian = loadPack("deshishana_bs", Bosnian.profile) { Bosnian.makeRestorer(loadInvariant: false) }
    private static var restorers: [Restorer?] { [serbian, croatian, bosnian] }

    // Prefer bare JSON from Bundle.main (the assembled .app); fall back to the library's
    // makeRestorer (Bundle.module) for `swift run`. The .app always hits the first path.
    private static func loadPack(_ name: String, _ profile: LanguageProfile, _ fallback: () -> Restorer?) -> Restorer? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return Restorer.load(jsonData: data, profile: profile, loadInvariant: false)
        }
        return fallback()
    }

    private var candidatesWindow: IMKCandidates? { AppDelegate.shared?.candidates }
    private var notFound: NSRange { NSRange(location: NSNotFound, length: NSNotFound) }

    // MARK: Lifecycle

    override func activateServer(_ sender: Any!) {
        buffer.removeAll(); previousWord = nil; clearCandidates()
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        commitBuffer(client: sender)
        super.deactivateServer(sender)
    }

    // MARK: Key handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            return false
        }

        // While the candidate window is up, a few keys drive the selection (everything else
        // falls through to normal typing, so the default flow keeps working).
        if candidatesWindow?.isVisible() == true {
            switch event.keyCode {
            case 126, 125, 116, 121:           // up / down / page up / page down
                candidatesWindow?.interpretKeyEvents([event])
                return true
            case 36, 76:                        // Return → accept the highlighted reading
                commit(highlighted ?? currentCandidates.first ?? buffer, client: sender, suffix: "")
                return true
            default:
                if let chs = event.characters, chs.count == 1, let n = Int(chs),
                   n >= 1, n <= currentCandidates.count {
                    commit(currentCandidates[n - 1], client: sender, suffix: "")   // number picks Nth
                    return true
                }
            }
        }

        switch event.keyCode {
        case 36, 76: // Return / keypad Enter
            commitBuffer(client: sender, suffix: "\n")
            return true
        case 48: // Tab
            commitBuffer(client: sender, suffix: "\t")
            return true
        case 51: // Backspace
            if !buffer.isEmpty {
                buffer.removeLast()
                updateMarkedText(client: sender)
                refreshCandidates()
                return true
            }
            return false
        case 53: // Escape
            if candidatesWindow?.isVisible() == true { clearCandidates(); return true }
            clearMarkedText(client: sender); buffer.removeAll()
            return true
        default:
            break
        }

        guard let text = event.characters, !text.isEmpty else { return false }
        var handled = false
        for scalar in text.unicodeScalars {
            let ch = Character(scalar)
            if isWordCharacter(ch) {
                buffer.append(ch)
                updateMarkedText(client: sender)
                refreshCandidates()
                handled = true
            } else {
                commitBuffer(client: sender, suffix: String(ch))
                handled = true
            }
        }
        return handled
    }

    private func isWordCharacter(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber }

    // MARK: Candidate window (IMKCandidates callbacks)

    override func candidates(_ sender: Any!) -> [Any]! { currentCandidates }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        commit(candidateString?.string ?? buffer, client: client(), suffix: "")
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        highlighted = candidateString?.string
    }

    /// Recompute the readings for the current buffer and show/hide the panel accordingly.
    private func refreshCandidates() {
        currentCandidates = ambiguousReadings(for: buffer)
        highlighted = currentCandidates.first
        guard let win = candidatesWindow else { return }
        if currentCandidates.count >= 2 {
            win.update()
            win.show(kIMKLocateCandidatesBelowHint)
        } else {
            win.hide()
        }
    }

    private func clearCandidates() {
        currentCandidates = []
        highlighted = nil
        candidatesWindow?.hide()
    }

    /// Accented readings for a bald word — only when there are ≥2 (genuine ambiguity, e.g.
    /// `casa` → časa / čaša / …). Returns the variants (cased to the typed word) plus the
    /// original "keep as typed" at the end. Empty when there is 0 or 1 reading.
    private func ambiguousReadings(for word: String) -> [String] {
        guard !word.isEmpty, word.allSatisfy({ $0.isLetter }) else { return [] }
        for r in Self.restorers {
            guard let r else { continue }
            for key in baldKeys(word.lowercased(), r.profile) {
                guard let cands = r.index[key] else { continue }
                let accented = cands.filter { $0 != key }
                guard accented.count >= 2 else { return [] }
                var out: [String] = []
                var seen = Set<String>()
                for c in accented {
                    let cased = applyCaseLike(word, c)
                    if seen.insert(cased).inserted { out.append(cased) }
                }
                if seen.insert(word).inserted { out.append(word) }   // keep-as-typed
                return out
            }
        }
        return []
    }

    /// Reconstruct the engine's bald lookup keys from the public profile rules (lowercase →
    /// pre-replacements → strip map → đ ↔ dj/d expansion). Mirrors the library's internal
    /// `baldKeys`, which isn't public.
    private func baldKeys(_ s0: String, _ p: LanguageProfile) -> [String] {
        var s = s0
        for (from, to) in p.preReplacements { s = s.replacingOccurrences(of: from, with: to) }
        s = String(s.map { p.stripMap[$0] ?? $0 })
        var variants = [s]
        for (ch, opts) in p.multiExpansions where !opts.isEmpty {
            let tok = String(ch)
            var next: [String] = []
            for v in variants {
                if v.contains(tok) { for o in opts { next.append(v.replacingOccurrences(of: tok, with: o)) } }
                else { next.append(v) }
            }
            variants = next
        }
        return variants
    }

    private func applyCaseLike(_ typed: String, _ lower: String) -> String {
        let letters = typed.filter { $0.isLetter }
        if letters.count > 1, typed == typed.uppercased() { return lower.uppercased() }
        if let f = typed.first, f.isUppercase { return lower.prefix(1).uppercased() + lower.dropFirst() }
        return lower
    }

    // MARK: Commit

    private func restore(_ word: String) -> String {
        let prev = previousWord
        for r in Self.restorers { if let fixed = r?.restore(word, prevWord: prev), fixed != word { return fixed } }
        return word
    }

    /// Default commit: restore the buffered word (top reading) and append a delimiter.
    private func commitBuffer(client sender: Any!, suffix: String = "") {
        guard let client = sender as? IMKTextInput else { clearCandidates(); return }
        if buffer.isEmpty {
            if !suffix.isEmpty { client.insertText(suffix, replacementRange: notFound) }
            clearCandidates()
            return
        }
        let original = buffer
        client.insertText(restore(original) + suffix, replacementRange: notFound)
        previousWord = original
        buffer.removeAll()
        clearCandidates()
    }

    /// Commit an explicitly chosen string (a candidate the user picked).
    private func commit(_ string: String, client sender: Any!, suffix: String) {
        guard let client = sender as? IMKTextInput else { clearCandidates(); return }
        if !buffer.isEmpty { previousWord = buffer }
        client.insertText(string + suffix, replacementRange: notFound)
        buffer.removeAll()
        clearCandidates()
    }

    // MARK: Marked text

    private func updateMarkedText(client sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        client.setMarkedText(buffer, selectionRange: NSRange(location: buffer.count, length: 0),
                             replacementRange: notFound)
    }

    private func clearMarkedText(client sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: notFound)
    }
}
