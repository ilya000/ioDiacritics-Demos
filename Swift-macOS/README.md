# ioDiacritics Demo

A tiny windowed macOS app that showcases the [`ioDiacritics`](../../ioDiacritics) library.

Paste or type **ošišana** (diacritic-stripped) Bosnian / Croatian / Serbian text — the kind
you get when someone types without `č ć š ž đ` — and the app **dešišava** it: restores the
missing diacritics, highlights every word it changed, and copies the result with one button.

```
Drzava takodje moze.   ->   Država takođe može.
nasa drzava            ->   naša država
```

## What it demonstrates

- **One-call restoration** — the whole UI is built on `restorePreparedText(_:)`. No network, no
  AI, fully offline.
- **Full databases, quality over memory** — unlike PolyType (a live keyboard that loads packs
  with `loadInvariant: false` to save RAM), this demo loads each pack with
  `loadInvariant: true`, materialising the full diacritic-free word set (tens to hundreds of
  thousands of words per language) for a proper `isLanguage` anchor and better detection.
- **Auto-detect (honest about BCS)** — the library ships no detector, so the demo scores each
  pack on balanced signals (confident edits + reverse-index coverage) in
  [`DemoEngine.detect`](Sources/DiacriticsDemo/DemoEngine.swift). Bosnian/Croatian/Serbian share
  almost all šišana→restored mappings, so most text is genuinely indistinguishable between the
  varieties — when the signals tie, the badge says **"Serbo-Croatian (BCS)"** rather than
  guessing a variety. Use the dropdown to force one.
- **Change highlighting** — a word-level diff marks exactly which words were fixed.
- **Reliability passport** — the footer shows the live `LangStats.summary` for the pack that ran.

## Run it

```bash
./run.sh          # build the .app and open it
# or
swift run         # plain SwiftPM run
```

`./build_app.sh` alone just produces `dist/ioDiacriticsDemo.app`.

## Layout

| File | Role |
|---|---|
| `Sources/DiacriticsDemo/App.swift` | `@main` SwiftUI app + window. |
| `Sources/DiacriticsDemo/ContentView.swift` | Two-pane UI, language picker, copy button, highlighting. |
| `Sources/DiacriticsDemo/DemoEngine.swift` | Restoration, auto-detect, and the diff — the only file that touches the library. |

Depends on `ioDiacritics` by local path (`../../ioDiacritics`), so it always builds against the
working copy next door.
