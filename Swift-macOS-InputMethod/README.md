# ioDiacritics Šišana Input Method

A macOS **Input Method Kit** demo for [`ioDiacritics`](https://github.com/ilya000/ioDiacritics).
It installs as an input source, so the user picks it like a keyboard layout and types stripped
Bosnian / Croatian / Serbian Latin text directly in any normal macOS text field:

```text
Drzava takodje moze.  ->  Država takođe može.
nasa drzava           ->  naša država
```

This is different from the windowed SwiftUI demo. There is no main editor window: the app is a
background input method bundle loaded by macOS when the input source is selected.

## MVP behavior

- buffers the current ASCII word as marked text;
- restores when the user types whitespace or punctuation;
- inserts the restored word plus the delimiter into the client app;
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
dist/ioDiacritics Šišana.app
```

## Install for the current user

```bash
./install_user.sh
```

Then log out/in, or restart TextInputMenuAgent:

```bash
killall TextInputMenuAgent
```

Open **System Settings -> Keyboard -> Input Sources**, add **ioDiacritics Šišana**, and select it
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
- ambiguous words can later open candidates while precision-first automatic restoration remains
  the default for confident cases.
