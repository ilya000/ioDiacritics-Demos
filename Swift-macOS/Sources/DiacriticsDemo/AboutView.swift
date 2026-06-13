import SwiftUI
import ioDiacritics

/// About panel: what the app is for, author, license, links, and which library build it was
/// compiled against. Shown as a sheet from the ⓘ button.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let demoRepo = URL(string: "https://github.com/ilya000/ioDiacritics-Demos")!
    private let libRepo  = URL(string: "https://github.com/ilya000/ioDiacritics")!

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 34))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ioDiacritics Demo")
                        .font(.title2.weight(.semibold))
                    Text("Restore Bosnian / Croatian / Serbian diacritics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // What it's for
            Text("""
            Paste **ošišana** text — Bosnian, Croatian, or Serbian written without its \
            diacritics (`č ć š ž đ`), the way it comes out when someone types on a plain \
            keyboard — and this app **dešišava** it: it restores the missing diacritics, \
            highlights every word it changed, and copies the result with one button. \
            Pick a language or let it auto-detect; the **Serbian (Cyrillic)** mode also \
            transliterates the result to Cyrillic (Држава такође може).

            It runs fully offline, with no AI and no network — just a deterministic, \
            precision-first dictionary engine. Handy for cleaning up chat, forum, OCR, or \
            legacy text, and for showing what the ioDiacritics library does.
            """)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("Author").foregroundColor(.secondary)
                    Text("iLya Os (Ilya V. Osipov)")
                }
                GridRow {
                    Text("License").foregroundColor(.secondary)
                    Text("MIT — demo source. See NOTICE for bundled-data terms.")
                }
                GridRow {
                    Text("Engine").foregroundColor(.secondary)
                    Text("ioDiacritics v\(IODiacritics.version)")
                }
                GridRow {
                    Text("Source").foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Link("Demo repo", destination: demoRepo)
                        Link("Library", destination: libRepo)
                    }
                }
            }
            .font(.callout)

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
