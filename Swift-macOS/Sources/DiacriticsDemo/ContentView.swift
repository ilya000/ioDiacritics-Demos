import SwiftUI
import AppKit
import ioDiacritics

struct ContentView: View {
    @State private var input: String = "Drzava takodje moze. Zelim da naucim nasu pjesmu i da je procitam svaki dan."
    @State private var language: DemoLanguage = .auto
    @State private var justCopied = false

    private var outcome: DemoEngine.Outcome {
        DemoEngine.restore(input, language: language)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            HStack(spacing: 0) {
                inputPane
                Divider()
                outputPane
            }
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 440)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text("ioDiacritics")
                    .font(.headline)
                Text("Restore č ć š ž đ in Bosnian / Croatian / Serbian")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if language == .auto {
                detectedBadge
            }

            Picker("Language", selection: $language) {
                ForEach(DemoLanguage.allCases) { lang in
                    Text(lang.menuLabel).tag(lang)
                }
            }
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var detectedBadge: some View {
        let label: String
        if outcome.ambiguous {
            // Varieties indistinguishable from this text — report honestly instead of guessing.
            label = "Serbo-Croatian (BCS)"
        } else {
            let name = outcome.usedLanguage.passportName ?? outcome.usedLanguage.menuLabel
            // passportName is "Српски / Serbian" style; show only the Latin half for a compact chip.
            label = name.split(separator: "/").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? name
        }
        return HStack(spacing: 5) {
            Image(systemName: "wand.and.stars")
                .font(.caption2)
            Text("Detected: \(label)")
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    // MARK: Panes

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("Ošišana — paste here", trailing: AnyView(
                Button("Clear") { input = "" }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .disabled(input.isEmpty)
            ))
            TextEditor(text: $input)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader(
                outcome.changedWords == 0 ? "Restored" : "Restored — \(outcome.changedWords) word\(outcome.changedWords == 1 ? "" : "s") fixed",
                trailing: AnyView(copyButton)
            )
            ScrollView {
                highlighted
                    .font(.system(size: 15))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The restored text with changed words drawn in the accent color + semibold.
    private var highlighted: Text {
        outcome.segments.reduce(Text("")) { acc, seg in
            let piece = seg.changed
                ? Text(seg.text).foregroundColor(.accentColor).fontWeight(.semibold)
                : Text(seg.text)
            return acc + piece
        }
    }

    private var copyButton: some View {
        Button {
            copy(outcome.restored)
        } label: {
            Label(justCopied ? "Copied" : "Copy", systemImage: justCopied ? "checkmark" : "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .disabled(outcome.restored.isEmpty)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if let summary = outcome.usedLanguage.statsSummary {
                Text(summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text("ioDiacritics v\(IODiacritics.version)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func paneHeader(_ title: String, trailing: AnyView) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { justCopied = false }
    }
}
