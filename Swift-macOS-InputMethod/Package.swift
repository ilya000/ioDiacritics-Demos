// swift-tools-version:5.9
import PackageDescription

// DiacriticsInputMethod -- a macOS Input Method Kit demo for ioDiacritics.
//
// It builds a background .app bundle that can be installed into
// ~/Library/Input Methods and selected like a keyboard layout. The controller buffers a typed
// ASCII word and commits the restored form when the user types whitespace or punctuation.
let package = Package(
    name: "DiacriticsInputMethod",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../ioDiacritics"),
    ],
    targets: [
        .executableTarget(
            name: "DiacriticsInputMethod",
            dependencies: [
                .product(name: "ioDiacriticsBosnian", package: "ioDiacritics"),
                .product(name: "ioDiacriticsCroatian", package: "ioDiacritics"),
                .product(name: "ioDiacriticsSerbian", package: "ioDiacritics"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("InputMethodKit"),
            ]
        ),
    ]
)

