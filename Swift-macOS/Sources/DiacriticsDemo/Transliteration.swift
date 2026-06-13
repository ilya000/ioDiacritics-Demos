import Foundation

/// Deterministic Serbian Gaj's-Latin → Cyrillic transliteration.
///
/// Used by the "Serbian (Cyrillic)" mode: the text is first restored to proper Latin
/// (`č ć š ž đ`) by the ioDiacritics Serbian pack, then converted here. The digraphs `dž`,
/// `lj`, `nj` map to single Cyrillic letters (`џ љ њ`); everything else is a 1:1 letter map.
/// Non-Serbian letters (`q w x y`), digits, and punctuation pass through unchanged.
///
/// This is intentionally a simple, dictionary-free mapping — it does not handle the rare
/// boundary cases where `n+j` / `d+ž` are genuinely separate letters (e.g. *injekcija*,
/// *nadživeti*). Good enough for a demo; PolyType/ioDiacritics carry the fuller logic.
enum SerbianCyrillic {
    private static let singles: [Character: Character] = [
        "a": "а", "b": "б", "c": "ц", "č": "ч", "ć": "ћ", "d": "д", "đ": "ђ",
        "e": "е", "f": "ф", "g": "г", "h": "х", "i": "и", "j": "ј", "k": "к",
        "l": "л", "m": "м", "n": "н", "o": "о", "p": "п", "r": "р", "s": "с",
        "š": "ш", "t": "т", "u": "у", "v": "в", "z": "з", "ž": "ж",
    ]
    private static let digraphs: [String: Character] = ["dž": "џ", "lj": "љ", "nj": "њ"]

    static func fromLatin(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        out.reserveCapacity(chars.count)
        var i = 0
        while i < chars.count {
            // Two-character digraph (case-insensitive); case taken from the first letter.
            if i + 1 < chars.count {
                let pair = (String(chars[i]) + String(chars[i + 1])).lowercased()
                if let cyr = digraphs[pair] {
                    out += chars[i].isUppercase ? String(cyr).uppercased() : String(cyr)
                    i += 2
                    continue
                }
            }
            let c = chars[i]
            if let lower = String(c).lowercased().first, let cyr = singles[lower] {
                out += c.isUppercase ? String(cyr).uppercased() : String(cyr)
            } else {
                out.append(c)   // passthrough: q/w/x/y, digits, punctuation, whitespace
            }
            i += 1
        }
        return out
    }
}
