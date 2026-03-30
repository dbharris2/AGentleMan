import SwiftUI

struct DiffView: View {
    let diffText: String
    @AppStorage(UserDefaultsKeys.terminalTheme) private var themeName = "Catppuccin Mocha"

    private var theme: GhosttyTheme? {
        GhosttyThemeLoader.load(named: themeName)
    }

    private var parsedLines: [(line: String, kind: LineKind, lang: String?)] {
        var result: [(String, LineKind, String?)] = []
        var currentLang: String?

        for line in diffText.components(separatedBy: "\n") {
            let kind = classify(line)
            if kind == .fileHeader {
                if let ext = SyntaxHighlighter.extensionFromDiffHeader(line) {
                    currentLang = SyntaxHighlighter.language(forExtension: ext)
                }
            }
            result.append((line, kind, currentLang))
        }
        return result
    }

    var body: some View {
        let bg = theme?.background
        let fg = theme?.foreground

        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, entry in
                    diffLine(entry.line, kind: entry.kind, lang: entry.lang, fg: fg)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: bg ?? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)))
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func diffLine(
        _ line: String,
        kind: LineKind,
        lang: String?,
        fg: NSColor?
    ) -> some View {
        let contextColor = Color(nsColor: fg ?? .labelColor).opacity(0.6)

        switch kind {
        case .fileHeader:
            Text(line)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(nsColor: fg ?? .white))
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))

        case .hunkHeader:
            Text(line)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(nsColor: .systemCyan))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cyan.opacity(0.06))

        case .added:
            highlightedText(line, prefix: "+", lang: lang, fallbackColor: Color(nsColor: .systemGreen))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))

        case .removed:
            highlightedText(line, prefix: "-", lang: lang, fallbackColor: Color(nsColor: .systemRed))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))

        case .context:
            highlightedText(line, prefix: " ", lang: lang, fallbackColor: contextColor)
                .padding(.horizontal, 8)

        case .meta:
            Text(line)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(contextColor)
                .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private func highlightedText(
        _ line: String,
        prefix: String,
        lang: String?,
        fallbackColor: Color
    ) -> some View {
        // Strip the diff prefix for highlighting, then display with prefix
        let code = line.hasPrefix(prefix) ? String(line.dropFirst()) : line
        if let highlighted = SyntaxHighlighter.highlight(code, language: lang) {
            Text(prefix) + Text(highlighted)
        } else {
            Text(line.isEmpty ? " " : line)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(fallbackColor)
        }
    }

    private enum LineKind {
        case fileHeader, hunkHeader, added, removed, meta, context
    }

    private func classify(_ line: String) -> LineKind {
        if line.hasPrefix("diff --git") {
            return .fileHeader
        }
        if line.hasPrefix("@@") {
            return .hunkHeader
        }
        if line.hasPrefix("+") {
            return .added
        }
        if line.hasPrefix("-") {
            return .removed
        }
        if line.hasPrefix("index ") || line.hasPrefix("--- ") || line.hasPrefix("+++ ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file") || line.hasPrefix("rename ") {
            return .meta
        }
        return .context
    }
}
