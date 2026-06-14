import Foundation
import ioDiacritics
import ioDiacriticsBosnian
import ioDiacriticsCroatian
import ioDiacriticsSerbian

/// The languages the demo offers, plus an Auto mode that detects which BCS variety the
/// text is written in. Each concrete case maps to one `ioDiacritics` language pack.
enum DemoLanguage: String, CaseIterable, Identifiable {
    case auto, bosnian, croatian, serbian, serbianCyrillic

    var id: String { rawValue }

    /// Short label for the dropdown.
    var menuLabel: String {
        switch self {
        case .auto:            return "Auto-detect"
        case .bosnian:         return "Bosnian"
        case .croatian:        return "Croatian"
        case .serbian:         return "Serbian (Latin)"
        case .serbianCyrillic: return "Serbian (Cyrillic)"
        }
    }

    /// After restoring with the Serbian pack, transliterate the Latin result to Serbian Cyrillic.
    var transliterateToCyrillic: Bool { self == .serbianCyrillic }

    /// Display name straight from the library's reliability passport (e.g. "Српски / Serbian").
    var passportName: String? {
        switch self {
        case .auto:            return nil
        case .bosnian:         return Bosnian.stats.language
        case .croatian:        return Croatian.stats.language
        case .serbian:         return Serbian.stats.language
        case .serbianCyrillic: return "Српски ћирилица / Serbian Cyrillic"
        }
    }

    /// The lazily-loaded restorer for this language (nil for `.auto`, or if a dictionary is missing).
    ///
    /// Unlike PolyType (a live keyboard that loads `Bosnian.shared` with `loadInvariant: false`
    /// to save RAM), this demo loads each pack with `loadInvariant: true`. That materialises the
    /// full diacritic-free word set (tens to hundreds of thousands of words per language), which
    /// powers a proper `isLanguage` anchor and much better auto-detection. The demo prioritises
    /// quality over memory, so it builds its own restorers instead of reusing the shared ones.
    var restorer: Restorer? {
        switch self {
        case .auto:            return nil
        case .bosnian:         return DemoPacks.bosnian
        case .croatian:        return DemoPacks.croatian
        case .serbian, .serbianCyrillic: return DemoPacks.serbian
        }
    }

    /// One-line reliability summary for the footer / About surface.
    var statsSummary: String? {
        switch self {
        case .auto:            return nil
        case .bosnian:         return Bosnian.stats.summary
        case .croatian:        return Croatian.stats.summary
        case .serbian, .serbianCyrillic: return Serbian.stats.summary
        }
    }

    /// The three concrete packs, in detection / tie-break preference order.
    static let concrete: [DemoLanguage] = [.serbian, .croatian, .bosnian]
}

/// Full-quality restorers loaded once with the invariant word set materialised. Heavier in RAM
/// than `Bosnian.shared` & co., but that is the explicit trade for this demo.
///
/// The dictionaries are loaded **directly from the app bundle** (`Bundle.main`) via the public
/// `Restorer.load`, NOT via the library's `makeRestorer` / `Bundle.module`. In a hand-assembled
/// `.app`, the SwiftPM resource bundles (`ioDiacritics_*.bundle`, which ship without an
/// `Info.plist`) can be rejected by `Bundle(url:)` under LaunchServices / Gatekeeper app
/// translocation — and `Bundle.module` then `fatalError`s. Loading the bare JSON we copy into
/// `Contents/Resources` sidesteps that entirely (worst case: a nil restorer, handled gracefully).
enum DemoPacks {
    static let bosnian: Restorer?  = load("deshishana_bs", Bosnian.profile)  { Bosnian.makeRestorer(loadInvariant: true) }
    static let croatian: Restorer? = load("deshishana_hr", Croatian.profile) { Croatian.makeRestorer(loadInvariant: true) }
    static let serbian: Restorer?  = load("deshishana_sr", Serbian.profile)  { Serbian.makeRestorer(loadInvariant: true) }

    /// Prefer the bare JSON in `Bundle.main` (the assembled `.app`); fall back to the library's
    /// `makeRestorer` (Bundle.module) when there is no app bundle — e.g. `swift run` during dev,
    /// where the resources live next to the SwiftPM binary instead. The `.app` always hits the
    /// first path, so `Bundle.module` is never reached there (no fatalError risk).
    private static func load(_ name: String, _ profile: LanguageProfile, _ fallback: () -> Restorer?) -> Restorer? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return Restorer.load(jsonData: data, profile: profile, loadInvariant: true)
        }
        return fallback()
    }
}

/// Stateless restoration + detection + diff helpers built on top of `ioDiacritics`.
enum DemoEngine {

    /// Result of restoring a text: the fixed string, which language actually ran, and a
    /// word-level diff so the UI can highlight what changed.
    struct Outcome {
        let restored: String
        let usedLanguage: DemoLanguage   // the concrete language that ran (never `.auto`)
        var ambiguous: Bool = false      // (auto mode) the BCS varieties couldn't be separated
        let segments: [Segment]
        let changedWords: Int
    }

    /// Result of auto-detection: the best concrete pack plus whether the varieties were actually
    /// distinguishable. BCS varieties share almost all šišana→restored mappings, so for most
    /// text the balanced signals tie and only the size-skewed invariant set differs — in that
    /// case `ambiguous` is true and the UI honestly reports "Serbo-Croatian" rather than guessing.
    struct Detection {
        var language: DemoLanguage = .serbian
        var ambiguous: Bool = false
    }

    /// A run of the restored text, flagged when the restorer changed it from the input.
    struct Segment: Identifiable {
        let id = UUID()
        let text: String
        let changed: Bool
    }

    /// Restore `text` under `language`. In `.auto` mode the best-matching pack is detected first.
    static func restore(_ text: String, language: DemoLanguage) -> Outcome {
        let resolved: DemoLanguage
        var ambiguous = false
        if language == .auto {
            let d = detect(text)
            resolved = d.language
            ambiguous = d.ambiguous
        } else {
            resolved = language
        }
        guard let restorer = resolved.restorer else {
            return Outcome(restored: text, usedLanguage: resolved, ambiguous: ambiguous,
                           segments: text.isEmpty ? [] : [Segment(text: text, changed: false)], changedWords: 0)
        }
        // Restore diacritics in Latin, and diff against the (Latin) input so "fixed" highlighting
        // reflects the diacritic edits — the real value — not the script change.
        let restoredLatin = restorer.restorePreparedText(text)
        var segments = diff(original: text, restored: restoredLatin)
        let changed = segments.reduce(0) { $0 + ($1.changed ? 1 : 0) }

        var restored = restoredLatin
        if resolved.transliterateToCyrillic {
            // Per-run transliteration == whole-string (digraphs lj/nj/dž never cross a run
            // boundary, since a word is a single run), so the changed flags carry over.
            restored = SerbianCyrillic.fromLatin(restoredLatin)
            segments = segments.map { Segment(text: SerbianCyrillic.fromLatin($0.text), changed: $0.changed) }
        }
        return Outcome(restored: restored, usedLanguage: resolved, ambiguous: ambiguous,
                       segments: segments, changedWords: changed)
    }

    // MARK: Detection

    /// Auto-detect the BCS variety. Each pack is scored on three signals, in priority order:
    ///   1. edits   — confident restorations the pack would make (balanced across packs);
    ///   2. idxCov  — words present in the fixable reverse-index (balanced, ~115-157k each);
    ///   3. langCov — words valid per `isLanguage`, incl. the invariant set (size-skewed: the
    ///                shipped Serbian invariant is far smaller, so this is only a last resort).
    /// `edits`/`idxCov` are the meaningful, comparable signals; if they fail to separate the
    /// winner from the runner-up, the varieties are genuinely indistinguishable from this text
    /// and the result is flagged `ambiguous` (the UI then says "Serbo-Croatian"). The chosen
    /// pack is still fine to restore with — tied packs produce near-identical output.
    static func detect(_ text: String) -> Detection {
        let words = wordTokens(text)
        guard !words.isEmpty else { return Detection() }

        struct Score { let lang: DemoLanguage; let edits: Int; let idxCov: Int; let langCov: Int }
        var scores: [Score] = []
        for lang in DemoLanguage.concrete {
            guard let r = lang.restorer else { continue }
            var edits = 0, idxCov = 0, langCov = 0
            for w in words {
                if r.index[w.lowercased()] != nil { idxCov += 1 }
                if r.isLanguage(w) { langCov += 1 }
                if let fixed = r.restore(w), fixed != w { edits += 1 }
            }
            scores.append(Score(lang: lang, edits: edits, idxCov: idxCov, langCov: langCov))
        }
        guard let best = scores.max(by: {
            ($0.edits, $0.idxCov, $0.langCov) < ($1.edits, $1.idxCov, $1.langCov)
        }) else { return Detection() }

        // Ambiguous if another pack ties the winner on the balanced signals (edits, idxCov) —
        // i.e. the win came only from the skewed invariant count or arbitrary order.
        let ambiguous = scores.contains { $0.lang != best.lang && $0.edits == best.edits && $0.idxCov == best.idxCov }
        return Detection(language: best.lang, ambiguous: ambiguous)
    }

    private static func wordTokens(_ text: String) -> [String] {
        var words: [String] = []
        var token = ""
        for ch in text {
            if ch.isLetter { token.append(ch) }
            else if !token.isEmpty { words.append(token); token = "" }
        }
        if !token.isEmpty { words.append(token) }
        return words
    }

    // MARK: Diff

    /// Split both strings into letter/number runs vs separator runs (the same split the engine
    /// uses), then zip them: separators and word count line up because `restorePreparedText`
    /// only ever rewrites the letters inside a word run. Adjacent runs of the same changed-ness
    /// are coalesced so highlighting reads as whole words, not character noise.
    static func diff(original: String, restored: String) -> [Segment] {
        let a = runs(original)
        let b = runs(restored)
        var out: [Segment] = []
        let n = min(a.count, b.count)
        for i in 0..<n {
            let changed = a[i] != b[i]
            if let last = out.last, last.changed == changed {
                out[out.count - 1] = Segment(text: last.text + b[i], changed: changed)
            } else {
                out.append(Segment(text: b[i], changed: changed))
            }
        }
        // Structures matched almost always; if they somehow diverge, append the tail verbatim.
        if b.count > n {
            let tail = b[n...].joined()
            out.append(Segment(text: tail, changed: false))
        }
        return out
    }

    /// Tokenise into maximal letter/number runs and separator runs, preserving order.
    private static func runs(_ text: String) -> [String] {
        var result: [String] = []
        var token = ""
        var tokenIsWord: Bool?
        for ch in text {
            let isWord = ch.isLetter || ch.isNumber
            if tokenIsWord == nil || tokenIsWord == isWord {
                token.append(ch); tokenIsWord = isWord
            } else {
                result.append(token); token = String(ch); tokenIsWord = isWord
            }
        }
        if !token.isEmpty { result.append(token) }
        return result
    }
}
