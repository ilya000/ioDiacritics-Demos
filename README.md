# ioDiacritics Demos

Showcase apps for the [`ioDiacritics`](https://github.com/ilya000/ioDiacritics) library —
restore stripped Bosnian / Croatian / Serbian Latin diacritics (`č ć š ž đ`) in **ošišana**
text:

```
Drzava takodje moze.   ->   Država takođe može.
nasa drzava            ->   naša država
```

![ioDiacritics Swift macOS demo restoring stripped text](docs/assets/macos-demo.png)

## Download & run (no build needed)

Don't want to build it? Grab the ready-made **signed & notarized** macOS app:

➡️ **[Download ioDiacriticsDemo.dmg](https://github.com/ilya000/ioDiacritics-Demos/releases/latest/download/ioDiacriticsDemo.dmg)** — ~5.8 MB, macOS 13+

Open the DMG, drag **ioDiacritics Demo** into Applications, launch it. It's signed with a
Developer ID and notarized by Apple, so it opens on any Mac with no Gatekeeper warnings — just
double-click. The cross-platform C++ build is built from source (see below).

Signed and notarized application bundles belong on **GitHub Releases** as downloadable assets,
not in the normal git history. The repository keeps source code, scripts, README files, and
licenses; release assets keep the ready-to-run `.dmg`, `.zip`, or notarized `.app` packages.

Each demo lives in its own subfolder, named **`Language-Platform(s)`**, and is a complete,
self-contained project. They share the same engine and dictionaries, but demonstrate different
product shapes: a windowed desktop app, a cross-platform C++ app, and a real macOS input source.

## Demo Versions

| Demo version | Language / binding | Platforms | UI stack | Source |
|---|---|---|---|---|
| Swift desktop demo | Swift / SwiftPM | macOS | SwiftUI native window | [`Swift-macOS`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Swift-macOS) |
| **Šišana** (input method / IME) | Swift / Input Method Kit | macOS | System input source with a candidate window | [`Swift-macOS-InputMethod`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Swift-macOS-InputMethod) |
| C++ cross-platform demo | C++17 / CMake | Windows, macOS, Linux | Dear ImGui + GLFW + OpenGL3 | [`Cpp-Windows-macOS-Linux`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Cpp-Windows-macOS-Linux) |

### ⌨️ Featured: Šišana — type with diacritics, anywhere

**Šišana** ([`Swift-macOS-InputMethod`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Swift-macOS-InputMethod))
turns the engine into a **macOS input method** — a real system input source you pick from the
keyboard menu, exactly like a layout. It is deeply **native to the OS**: it works in **every**
app (Mail, Notes, browsers, chat, code editors), with **no window, no copy-paste, no
Accessibility permission, fully offline**. Type bald Latin and the diacritics appear as you go
(`citaj` → `čitaj`).

For genuinely ambiguous words it shows the **system candidate window — the same
Chinese/Japanese-IME mechanism** — and offers the valid readings (`casa` →
**časa · čaša · ćasa**); you pick one with a number key (`1`–`9`) or arrows + Return. Confident,
unambiguous words never interrupt you. It is the most natural way to write šišana
Bosnian/Croatian/Serbian: keep typing the easy way, and your text comes out correct — right
where you are typing, in any application.

**Download & install (macOS 13+, signed & notarized):**

➡️ **[Download Šišana (Sisana-InputMethod.dmg)](https://github.com/ilya000/ioDiacritics-Demos/releases/latest/download/Sisana-InputMethod.dmg)** — ~5.9 MB

1. Open the DMG and **drag `Šišana` into the `Input Methods` folder** (you may be asked for your
   admin password).
2. **System Settings → Keyboard → Input Sources → ＋**, add **Šišana**.
3. Pick **Šišana** from the input-source menu in the menu bar and start typing.

(Prefer to build it yourself? `cd Swift-macOS-InputMethod && ./install_user.sh` installs it for
the current user.)

The input-method demo is intentionally a Swift MVP. The production direction is an
Objective-C++ IMK wrapper around the shared C++ core: native macOS Input Method Kit integration
outside, one portable restoration engine inside.

Repository links:

- Main library: [`ilya000/ioDiacritics`](https://github.com/ilya000/ioDiacritics)
- All demos: [`ilya000/ioDiacritics-Demos`](https://github.com/ilya000/ioDiacritics-Demos)
- Swift/macOS demo: [`Swift-macOS`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Swift-macOS)
- Swift/macOS input method: [`Swift-macOS-InputMethod`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Swift-macOS-InputMethod)
- C++ Windows/macOS/Linux demo: [`Cpp-Windows-macOS-Linux`](https://github.com/ilya000/ioDiacritics-Demos/tree/main/Cpp-Windows-macOS-Linux)

All demos link the **same** library — Swift demos via SwiftPM, the C++ demo via the library's
own C++17 port — so the engine, dictionaries, and quality numbers are identical. The windowed
demos load the full dictionaries (the invariant word set included) for maximum quality and
honest BCS auto-detection; the input-method demo uses lightweight live-keyboard semantics.

## Repository layout

```
ioDiacritics-Demos/
├── Swift-macOS/                 # SwiftUI windowed demo (swift build / build_app.sh)
├── Swift-macOS-InputMethod/     # Input Method Kit demo installed as a macOS input source
└── Cpp-Windows-macOS-Linux/     # Dear ImGui demo (CMake + FetchContent)
```

The demos depend on the `ioDiacritics` library checked out next to this folder
(`../ioDiacritics`). See each subfolder's `README.md` for build & run instructions.

## Adding another demo

Create a new `Language-Platform(s)` subfolder (e.g. `Kotlin-Android`, `Rust-CrossPlatform`,
`TypeScript-Web`), depend on the appropriate binding/port of `ioDiacritics`, and add a row to
the table above.

## License

Demo source code is licensed under the **MIT License** — see [LICENSE](LICENSE).

The demos themselves bundle no dictionaries and vendor no libraries. Anything you
**distribute** (a built `.app` or binary) additionally includes the ioDiacritics dictionaries
(separate data provenance) and, for the C++ demo, Dear ImGui (MIT), GLFW (zlib/libpng) and the
Roboto font (Apache-2.0). See [NOTICE.md](NOTICE.md) before shipping a public binary.

The demo apps are provided **"as is", without warranties of any kind**, to the fullest extent permitted by applicable law. By downloading or using them you accept the [terms of use](https://ctrl8.com/legal.html). The signed, notarized macOS build is on the [releases page](https://github.com/ilya000/ioDiacritics-Demos/releases).
