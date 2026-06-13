import Foundation

/// Headless verification of the demo engine — restoration, auto-detect, and the diff —
/// without launching the GUI. Run with `swift run DiacriticsDemo --selftest`.
enum DemoSelfTest {
    static func run() {
        var failures = 0

        func check(_ label: String, _ pass: Bool, _ detail: String) {
            print("\(pass ? "PASS" : "FAIL")  \(label)  —  \(detail)")
            if !pass { failures += 1 }
        }

        // 1. Restoration produces the expected diacritics, per fixed language.
        let srOut = DemoEngine.restore("Drzava takodje moze.", language: .serbian)
        check("serbian restore", srOut.restored == "Država takođe može.", srOut.restored)

        let hrOut = DemoEngine.restore("nasa drzava", language: .croatian)
        check("croatian restore", hrOut.restored == "naša država", hrOut.restored)

        let bsOut = DemoEngine.restore("Drzava takodjer moze.", language: .bosnian)
        check("bosnian restore", bsOut.restored == "Država također može.", bsOut.restored)

        // 2. Change count is reported and matches highlighted segments.
        check("changed-word count", srOut.changedWords == 3, "\(srOut.changedWords) changed")
        let highlightedJoined = srOut.segments.map(\.text).joined()
        check("segments reconstruct text", highlightedJoined == srOut.restored, highlightedJoined)
        check("only changed words flagged",
              srOut.segments.filter(\.changed).allSatisfy { $0.text.contains(where: { $0.isLetter }) },
              srOut.segments.filter(\.changed).map(\.text).joined(separator: "|"))

        // 3. Auto-detect resolves to a concrete pack and restores.
        let autoOut = DemoEngine.restore("Drzava takodje moze.", language: .auto)
        check("auto resolves concrete", autoOut.usedLanguage != .auto, autoOut.usedLanguage.menuLabel)
        check("auto restores", autoOut.restored.contains("ž") || autoOut.restored.contains("đ"), autoOut.restored)

        // 4. Empty input is safe.
        let empty = DemoEngine.restore("", language: .auto)
        check("empty input safe", empty.restored.isEmpty && empty.changedWords == 0, "ok")

        // 5. Already-correct text is left alone (precision-first).
        let clean = DemoEngine.restore("Država može.", language: .serbian)
        check("clean text unchanged", clean.changedWords == 0, clean.restored)

        // 6. Auto-detect honesty: BCS varieties share the šišana→restored mappings, so the
        //    balanced signals can't separate them — detection must flag this, not guess.
        let det = DemoEngine.detect("Drzava takodje moze. Nasa pjesma je lijepa.")
        check("bcs flagged ambiguous", det.ambiguous, det.ambiguous ? "ambiguous" : "claimed certainty")
        check("ambiguous still resolves a pack", det.language != .auto, det.language.menuLabel)
        let am = DemoEngine.restore("Drzava takodje moze.", language: .auto)
        check("ambiguous restores correctly", am.restored == "Država takođe može.", am.restored)

        // 7. Serbian Cyrillic: restore + transliterate to Cyrillic; "fixed" count is the
        //    diacritic edits (computed in Latin), not the script change.
        let cyr = DemoEngine.restore("Drzava takodje moze.", language: .serbianCyrillic)
        check("serbian cyrillic restore", cyr.restored == "Држава такође може.", cyr.restored)
        check("cyrillic fixed-count is diacritics", cyr.changedWords == 3, "\(cyr.changedWords) changed")
        // Digraph + standalone transliteration sanity.
        check("cyrillic digraphs", SerbianCyrillic.fromLatin("Ljubav njegova džak ĐAK") == "Љубав његова џак ЂАК",
              SerbianCyrillic.fromLatin("Ljubav njegova džak ĐAK"))

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILURE(S)")
        if failures > 0 { exit(1) }
    }
}
