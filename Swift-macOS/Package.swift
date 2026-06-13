// swift-tools-version:5.9
import PackageDescription

// DiacriticsDemo — a tiny windowed macOS app that showcases the sibling `ioDiacritics`
// library: paste/type ošišana (diacritic-stripped) Bosnian/Croatian/Serbian text, the app
// "dešišava" it (restores č/ć/š/ž/đ), highlights what changed, and copies the result with
// one button. Language is picked from a dropdown or auto-detected. Depends on the library
// by local path so the demo always builds against the working copy next door.
let package = Package(
    name: "DiacriticsDemo",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../ioDiacritics"),
    ],
    targets: [
        .executableTarget(
            name: "DiacriticsDemo",
            dependencies: [
                .product(name: "ioDiacriticsBosnian", package: "ioDiacritics"),
                .product(name: "ioDiacriticsCroatian", package: "ioDiacritics"),
                .product(name: "ioDiacriticsSerbian", package: "ioDiacritics"),
            ]
        ),
    ]
)
