import SwiftUI
import ioDiacritics
import ioDiacriticsBosnian
import ioDiacriticsCroatian
import ioDiacriticsSerbian

/// Detailed About panel: what the app is, a real explanation of the ioDiacritics library it
/// showcases, live dictionary metrics, author, license, and repository links. Shown as a sheet
/// from the ⓘ button.
struct AboutView: View {
    /// Scene id for the About window (opened via `openWindow`).
    static let windowID = "about"

    @Environment(\.dismiss) private var dismiss

    private let demoRepo   = URL(string: "https://github.com/ilya000/ioDiacritics-Demos")!
    private let libRepo    = URL(string: "https://github.com/ilya000/ioDiacritics")!
    private let authorPage = URL(string: "https://github.com/ilya000")!
    /// The ctrl8 collection — every tool by iLya Os in one place. Shown at the
    /// top of About so users of any app can discover the others.
    private let website    = URL(string: "https://www.ctrl8.com")!

    // Live reliability passports straight from the bundled language packs.
    private var packs: [(name: String, stats: LangStats)] {
        [("Bosnian", Bosnian.stats), ("Croatian", Croatian.stats), ("Serbian", Serbian.stats)]
    }
    private func pct(_ v: Double?) -> String {
        guard let v else { return "—" }
        // A measured 100% just means "no wrong edits in this finite sample" — not a guarantee.
        // Showing a bare "100.0%" reads as an overclaim, so report it as "≈100%".
        if v >= 0.9995 { return "≈100%" }
        return String(format: "%.1f%%", v * 100)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                whatItDoes
                Divider()
                aboutLibrary
                Divider()
                languageStats
                Divider()
                facts
            }
            .padding(24)
        }
        .frame(width: 520, height: 640)
        .overlay(alignment: .bottomTrailing) {
            Button("Close") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 38))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("ioDiacritics Demo")
                    .font(.title.weight(.semibold))
                Text("Restore Bosnian · Croatian · Serbian diacritics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("App v\(appVersion) · engine ioDiacritics v\(IODiacritics.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 5) {
                    Text("Part of")
                        .foregroundColor(.secondary)
                    Link("ctrl8 — www.ctrl8.com", destination: website)
                }
                .font(.callout)
                .padding(.top, 2)
            }
        }
    }

    private var whatItDoes: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("What it does")
            Text("""
            Paste **ošišana** text — Bosnian, Croatian, or Serbian written without its diacritics \
            (`č ć š ž đ`), the way it comes out when someone types on a plain keyboard — and the \
            app **dešišava** it: it restores the missing marks, highlights every word it changed, \
            and copies the result with one button. Pick a language or let it auto-detect; the \
            **Serbian (Cyrillic)** mode also transliterates the result to Cyrillic \
            (*Држава такође може*). Handy for cleaning up chat, forum, OCR, or legacy text.
            """)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutLibrary: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("About the ioDiacritics library")
            Text("""
            The restoration is done by **ioDiacritics**, a small, offline, **AI-free** engine for \
            the Serbo-Croatian / BCS macrolanguage (ISO 639-3 `hbs`). It is deterministic: a \
            reverse-index dictionary built from a *bald* (stripped) surface form to its valid \
            accented candidates, plus a few conservative guards (digraph `dž`, the `đ` ↔ `dj`/`d` \
            conventions, a numeric guard for words like *sto* = 100). It is **precision-first** — \
            when a word is ambiguous, it leaves it untouched rather than risk a wrong edit.

            Everything runs locally: no network, no machine-learning model, no GPU, and no text \
            ever leaves the device. Bosnian, Croatian and Serbian are treated as parallel \
            first-tier packs (separate dictionaries and rules), which is why this demo reports \
            *Serbo-Croatian (BCS)* when the text can't be told apart between varieties. Each pack \
            ships its own validated dictionary and reliability passport (below).
            """)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Link("Library on GitHub", destination: libRepo)
                Link("This demo on GitHub", destination: demoRepo)
            }
            .font(.callout)
            .padding(.top, 2)
        }
    }

    private var languageStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Language statistics")
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
                GridRow {
                    Text("Language").gridColumnAlignment(.leading)
                    Text("Dictionary").gridColumnAlignment(.trailing)
                    Text("Recall").gridColumnAlignment(.trailing)
                    Text("Edit precision").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                Divider().gridCellColumns(4)
                ForEach(packs, id: \.name) { p in
                    GridRow {
                        Text(p.name)
                        Text("\(p.stats.dictKeys.formatted()) words")
                        Text(pct(p.stats.recall))
                        Text(pct(p.stats.editPrecision))
                    }
                }
            }
            .font(.callout.monospacedDigit())
            Text("Recall = strippable words restored; edit precision = of the edits made, how many are right. Measured on finite validated corpora, so ≈100% means no wrong edits were seen in the sample — not a guarantee. See the library's RESEARCH.md.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var facts: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Author").foregroundColor(.secondary).gridColumnAlignment(.leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("iLya Os (Ilya V. Osipov)")
                    Link("github.com/ilya000", destination: authorPage).font(.callout)
                }
            }
            GridRow {
                Text("License").foregroundColor(.secondary)
                Text("MIT for the demo source. Bundled dictionary data has its own provenance — see the repo's NOTICE.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            GridRow {
                Text("Engine").foregroundColor(.secondary)
                Text("ioDiacritics v\(IODiacritics.version) (linked from the sibling library checkout)")
            }
        }
        .font(.callout)
        .padding(.bottom, 28)   // clear the Close button
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.headline)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}
