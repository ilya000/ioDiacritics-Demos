# ioDiacritics Demos

Showcase apps for the [`ioDiacritics`](../ioDiacritics) library — restore stripped
Bosnian / Croatian / Serbian Latin diacritics (`č ć š ž đ`) in **ošišana** text:

```
Drzava takodje moze.   ->   Država takođe može.
nasa drzava            ->   naša država
```

Each demo lives in its own subfolder, named **`Language-Platform(s)`**, and is a complete,
self-contained project. They share the same idea — paste/type ošišana text, restore it,
highlight what changed, copy with one button, auto-detect or pick the language — but target
different stacks so you can see the library working natively on each.

| Folder | Language | Platforms | UI stack |
|---|---|---|---|
| [`Swift-macOS`](Swift-macOS) | Swift | macOS | SwiftUI (native window) |
| [`Cpp-Windows-macOS-Linux`](Cpp-Windows-macOS-Linux) | C++17 | Windows, macOS, Linux | Dear ImGui + GLFW + OpenGL3 |

Both link the **same** library — the Swift demo via SwiftPM, the C++ demo via the library's
own C++17 port — so the engine, dictionaries, and quality numbers are identical. Both load the
full dictionaries (the invariant word set included) for maximum quality, and both report
**"Serbo-Croatian (BCS)"** when the variety genuinely can't be told apart from the text.

## Repository layout

```
ioDiacritics-Demos/
├── Swift-macOS/                 # SwiftUI demo (swift build / build_app.sh)
└── Cpp-Windows-macOS-Linux/     # Dear ImGui demo (CMake + FetchContent)
```

The demos depend on the `ioDiacritics` library checked out next to this folder
(`../ioDiacritics`). See each subfolder's `README.md` for build & run instructions.

## Adding another demo

Create a new `Language-Platform(s)` subfolder (e.g. `Kotlin-Android`, `Rust-CrossPlatform`,
`TypeScript-Web`), depend on the appropriate binding/port of `ioDiacritics`, and add a row to
the table above.
