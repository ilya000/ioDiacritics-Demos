# Šišana — type with diacritics, anywhere

**Write šišana Bosnian/Croatian/Serbian the easy way and let your text come out correct.**

A macOS **Input Method Kit** showcase for [`ioDiacritics`](https://github.com/ilya000/ioDiacritics).
It installs as a system input source you pick from the keyboard menu, just like a layout — then you
type stripped Latin directly in **any** app and the diacritics appear as you go. No window, no
copy-paste, no Accessibility permission, fully offline:

```text
Drzava takodje moze.  ->  Država takođe može.
nasa drzava           ->  naša država
```

There is no main editor window: the app is a background input-method bundle loaded by macOS when
the input source is selected.

## Candidate readings — Chinese-IME style

When a word is genuinely ambiguous, Šišana pops the **system candidate window** —
the same UI Chinese/Japanese input methods use — and offers every valid reading:

```text
casa  ->  časa · čaša · ćasa
cas   ->  čas · ćas
vece  ->  veće · veče
```

Pick a reading with a **number key (1–9)** or **↑/↓ + Return**; or just keep typing and a space /
punctuation commits the most likely one. Confident, unambiguous words never interrupt you — the
candidate window appears only when there's a real choice to make.

## MVP behavior

- buffers the current ASCII word as marked text;
- restores when the user types whitespace or punctuation;
- offers the system candidate window when a bald word has several accented readings;
- inserts the restored (or chosen) word plus the delimiter into the client app;
- uses `ioDiacritics` offline dictionaries, no network and no Accessibility permission;
- uses live/keyboard semantics, so only the left neighbor is available for numeric guards.

The first demo build ships one BCS/Serbo-Croatian input source. It restores with a conservative
auto strategy: try Serbian, Croatian, then Bosnian, and keep the original word if no pack makes a
confident edit. Dedicated Bosnian/Croatian/Serbian/Cyrillic input modes can be added once the
basic IMK bundle is stable.

## Build

```bash
./build_app.sh
```

The script creates:

```text
dist/Šišana.app
```

## Install for the current user

```bash
./install_user.sh
```

Then log out/in, or restart TextInputMenuAgent:

```bash
killall TextInputMenuAgent
```

Open **System Settings -> Keyboard -> Input Sources**, add **Šišana**, and select it
from the menu bar input-source menu.

## Notes

- Secure password fields and some protected contexts may bypass custom input methods.
- For public distribution, sign and notarize the `.app` bundle before packaging, then attach
  the signed `.dmg` or `.zip` to a GitHub Release.
- The bundle is intended for `~/Library/Input Methods/` or `/Library/Input Methods/`, not
  `/Applications`.

## Production direction

This Swift project is the fastest way to validate the Input Method Kit bundle, installation
flow, and live-keyboard behavior. The production-grade input source is planned as a thin
Objective-C++ wrapper over the shared C++ `ioDiacritics` core:

- Objective-C++ handles `IMKServer`, `IMKInputController`, candidate UI, signing, and the
  macOS runtime details;
- C++ keeps the portable restoration engine shared with Windows, Linux, and future platforms;
- the candidate window for ambiguous words is already implemented in this Swift MVP (via
  `IMKCandidates`), with precision-first automatic restoration as the default for confident cases.
