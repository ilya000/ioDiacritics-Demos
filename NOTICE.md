# Notices

These demos are authored and maintained by **iLya Os**.

Legal name: **Ilya V. Osipov**
GitHub: <https://github.com/ilya000>

The demo source code in this repository (`Swift-macOS/`, `Cpp-Windows-macOS-Linux/`,
build scripts, and documentation) is licensed under the MIT License. See `LICENSE`.

This repository contains **demo source only**. It bundles no dictionaries and vendors no
third-party libraries — those are pulled from their sources at build time. The notices below
therefore apply to anything you **distribute** (a built `.app`, an installer, a binary), not to
this repository's own files.

## The ioDiacritics library and its dictionaries

Both demos depend on the sibling [`ioDiacritics`](../ioDiacritics) library (MIT) and, at build
or run time, load its bundled `deshishana_*.json` dictionaries. Those dictionaries are
generated artifacts derived from third-party lexical and corpus resources and are **not**
purely MIT-licensed — they carry their own provenance and attribution requirements
(turanjanin/serbian-language-tools, clarinsi/redi, hermitdave/FrequencyWords, Wortschatz
Leipzig, Hunspell dictionaries, and others).

Before shipping any public binary that includes those dictionaries, read the library's
`ioDiacritics/NOTICE.md` and `ioDiacritics/docs/DATA_LICENSE_AUDIT.md`.

## Third-party components (fetched at build time)

The `Cpp-Windows-macOS-Linux` demo fetches and links the following via CMake `FetchContent`.
They are not redistributed in this repository, but a packaged build embeds them:

- **Dear ImGui** — MIT License — <https://github.com/ocornut/imgui>
- **GLFW** — zlib/libpng License — <https://www.glfw.org/>
- **Roboto** (`Roboto-Medium.ttf`, shipped inside the Dear ImGui source tree and loaded for
  Latin Extended-A + Cyrillic glyphs) — Apache License 2.0 —
  <https://github.com/googlefonts/roboto>

The `Swift-macOS` demo uses only the system SwiftUI/AppKit frameworks plus the `ioDiacritics`
Swift package.
