import SwiftUI

struct SideBySideDiffView: View {
    let diffText: String
    @AppStorage(UserDefaultsKeys.terminalTheme) private var themeName = "Catppuccin Mocha"

    private var theme: GhosttyTheme? {
        GhosttyThemeLoader.load(named: themeName)
    }

    private var rows: [DiffRow] {
        parseSideBySide(diffText)
    }

    var body: some View {
        let bg = theme?.background
        let fg = theme?.foreground

        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case let .fileHeader(text):
                        Text(text)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(nsColor: fg ?? .white))
                            .padding(.horizontal, 8)
                            .padding(.top, 12)
                            .padding(.bottom, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.08))

                    case let .hunkHeader(text):
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(nsColor: .systemCyan))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cyan.opacity(0.06))

                    case let .pair(left, right, lang):
                        HStack(spacing: 0) {
                            sideCell(left, lang: lang, fg: fg)
                            Divider()
                            sideCell(right, lang: lang, fg: fg)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: bg ?? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)))
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func sideCell(_ cell: SideCell, lang: String?, fg: NSColor?) -> some View {
        let contextColor = Color(nsColor: fg ?? .labelColor).opacity(0.6)

        let bgColor = switch cell.kind {
        case .added: Color.green.opacity(0.1)
        case .removed: Color.red.opacity(0.1)
        case .context, .empty: Color.clear
        }

        let fallbackColor = switch cell.kind {
        case .added: Color(nsColor: .systemGreen)
        case .removed: Color(nsColor: .systemRed)
        case .context: contextColor
        case .empty: Color.clear
        }

        if cell.kind == .empty {
            Text(" ")
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let highlighted = SyntaxHighlighter.highlight(cell.text, language: lang) {
            Text(highlighted)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bgColor)
        } else {
            Text(cell.text.isEmpty ? " " : cell.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(fallbackColor)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bgColor)
        }
    }
}

// MARK: - Parsing

private enum DiffRow {
    case fileHeader(String)
    case hunkHeader(String)
    case pair(SideCell, SideCell, lang: String?)
}

private struct SideCell {
    let text: String
    let kind: CellKind

    enum CellKind {
        case context, added, removed, empty
    }

    static let blank = SideCell(text: "", kind: .empty)
}

private func parseSideBySide(_ diff: String) -> [DiffRow] {
    var rows: [DiffRow] = []
    let lines = diff.components(separatedBy: "\n")
    var currentLang: String?

    var removedBuffer: [String] = []
    var addedBuffer: [String] = []

    func flushBuffers() {
        let maxCount = max(removedBuffer.count, addedBuffer.count)
        for i in 0 ..< maxCount {
            let left = i < removedBuffer.count
                ? SideCell(text: removedBuffer[i], kind: .removed)
                : SideCell.blank
            let right = i < addedBuffer.count
                ? SideCell(text: addedBuffer[i], kind: .added)
                : SideCell.blank
            rows.append(.pair(left, right, lang: currentLang))
        }
        removedBuffer.removeAll()
        addedBuffer.removeAll()
    }

    for line in lines {
        if line.hasPrefix("diff --git") {
            flushBuffers()
            if let ext = SyntaxHighlighter.extensionFromDiffHeader(line) {
                currentLang = SyntaxHighlighter.language(forExtension: ext)
            }
            rows.append(.fileHeader(line))
        } else if line.hasPrefix("@@") {
            flushBuffers()
            rows.append(.hunkHeader(line))
        } else if line.hasPrefix("index ") || line.hasPrefix("--- ") || line.hasPrefix("+++ ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file") || line.hasPrefix("rename ") {
            // Skip meta lines
        } else if line.hasPrefix("-") {
            removedBuffer.append(String(line.dropFirst()))
        } else if line.hasPrefix("+") {
            addedBuffer.append(String(line.dropFirst()))
        } else {
            flushBuffers()
            let text = line.hasPrefix(" ") ? String(line.dropFirst()) : line
            let cell = SideCell(text: text, kind: .context)
            rows.append(.pair(cell, cell, lang: currentLang))
        }
    }

    flushBuffers()
    return rows
}
