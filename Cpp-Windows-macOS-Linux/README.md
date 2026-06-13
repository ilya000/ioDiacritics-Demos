# ioDiacritics Demo (C++ / Dear ImGui)

A **cross-platform** desktop demo for the [`ioDiacritics`](../../ioDiacritics) library — one
window where you paste or type **ošišana** (diacritic-stripped) Bosnian / Croatian / Serbian
text and it **dešišava** it: restores `č ć š ž đ`, highlights every word it changed, and
copies the result with one button. Language is picked from a dropdown or auto-detected.

```
Drzava takodje moze.   ->   Država takođe može.
nasa drzava            ->   naša država
```

Unlike the macOS-only SwiftUI demo (`../Swift-macOS`), this one builds and runs on
**Windows, macOS, and Linux** — because it links the library's own **C++17 port**
(`../../ioDiacritics/cpp`, the same engine and dictionaries, same quality numbers) and draws its
UI with **Dear ImGui + GLFW + OpenGL3**. No system GUI toolkit to install: GLFW and Dear ImGui
are vendored at configure time via CMake `FetchContent`.

## What it demonstrates

- **One-call restoration** — the UI is built on `Restorer::restore_prepared_text`.
- **Full databases, quality over memory** — unlike PolyType (a live keyboard that skips the
  invariant set to save RAM), this demo loads every pack with `load_invariant=true`,
  materialising the full diacritic-free word set for a proper `is_language` anchor and better
  detection. Startup reads ~400k index keys + ~330k invariant words across the three packs.
- **Auto-detect (honest about BCS)** — the library ships no detector, so `detect()` scores each
  pack on balanced signals (confident edits + reverse-index coverage). Bosnian/Croatian/Serbian
  share almost all šišana→restored mappings, so most text is genuinely indistinguishable between
  the varieties — when the signals tie, the badge says **"Serbo-Croatian (BCS)"** rather than
  guessing. Use the dropdown to force one.
- **Change highlighting** — a word-level diff colours exactly which words were fixed.
- **Reliability passport** — the footer shows the live `LangStats::summary()` for the pack that ran.

## Build & run

Requirements: **CMake 3.16+**, a **C++17 compiler**, **git** (Xcode CLT on macOS; a desktop
OpenGL dev setup on Linux). First configure needs network to fetch GLFW + Dear ImGui.

```bash
./build.sh                      # configure + build  ->  build/iodiacritics_demo
./build/iodiacritics_demo       # run the window
./build/iodiacritics_demo --selftest   # headless engine check (CI-friendly, no window)
```

Or drive CMake directly:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

### Dictionaries

The bundled `deshishana_*.json` dictionaries are loaded at runtime from the sibling library
checkout. Resolution order:

1. `argv[1]` — a path to the `ioDiacritics` repo root, if given;
2. the `IODIACRITICS_REPO_ROOT` environment variable;
3. the compile-time path baked in by CMake (the sibling `../../ioDiacritics`);
4. a `./data/` directory next to the binary (for a packaged build — copy the three JSON files there).

## Layout

| File | Role |
|---|---|
| `src/main.cpp` | Everything: engine wrapper (restore / detect / diff), the ImGui UI, and `--selftest`. |
| `CMakeLists.txt` | FetchContent GLFW + Dear ImGui, link `ioDiacritics::cpp`, build the app. |
| `build.sh` | Convenience configure+build with sensible defaults. |

## Windows / Linux notes

- **Linux**: install OpenGL + X11/Wayland dev packages GLFW needs, e.g. on Debian/Ubuntu
  `sudo apt install libgl1-mesa-dev xorg-dev`. Then `./build.sh`.
- **Windows**: configure with the Visual Studio generator
  (`cmake -S . -B build -G "Visual Studio 17 2022"`) and build
  (`cmake --build build --config Release`). MSVC 2019+ has the needed C++17 support.
