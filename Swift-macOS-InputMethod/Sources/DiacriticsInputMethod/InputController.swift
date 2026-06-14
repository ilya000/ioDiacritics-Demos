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

    private static let serbian = Serbian.makeRestorer(loadInvariant: false)
    private static let croatian = Croatian.makeRestorer(loadInvariant: false)
    private static let bosnian = Bosnian.makeRestorer(loadInvariant: false)

    override func activateServer(_ sender: Any!) {
        buffer.removeAll()
        previousWord = nil
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        commitBuffer(client: sender)
        super.deactivateServer(sender)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            return false
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
                return true
            }
            return false
        case 53: // Escape
            clearMarkedText(client: sender)
            buffer.removeAll()
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
                handled = true
            } else {
                commitBuffer(client: sender, suffix: String(ch))
                handled = true
            }
        }
        return handled
    }

    private func isWordCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber
    }

    private func restore(_ word: String) -> String {
        let prev = previousWord
        if let fixed = Self.serbian?.restore(word, prevWord: prev), fixed != word { return fixed }
        if let fixed = Self.croatian?.restore(word, prevWord: prev), fixed != word { return fixed }
        if let fixed = Self.bosnian?.restore(word, prevWord: prev), fixed != word { return fixed }
        return word
    }

    private func commitBuffer(client sender: Any!, suffix: String = "") {
        guard let client = sender as? IMKTextInput else { return }

        if buffer.isEmpty {
            if !suffix.isEmpty {
                client.insertText(suffix, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            return
        }

        let original = buffer
        let restored = restore(original)
        let committed = restored + suffix
        client.insertText(committed, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        previousWord = original
        buffer.removeAll()
    }

    private func updateMarkedText(client sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        let range = NSRange(location: buffer.count, length: 0)
        client.setMarkedText(buffer, selectionRange: range,
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    private func clearMarkedText(client sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}

