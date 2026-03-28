import AppKit

struct GhosttyTheme {
    var palette: [Int: NSColor] = [:]
    var background: NSColor = .black
    var foreground: NSColor = .white
    var cursorColor: NSColor = .white
    var selectionBackground: NSColor = .gray
    var selectionForeground: NSColor = .white

    /// The 16-color ANSI palette plus foreground/background as a 18-element array
    /// matching SwiftTerm's `installColors` format:
    /// [ansi0..ansi15, foreground, background]
    var swiftTermColors: [NSColor] {
        var colors: [NSColor] = []
        for i in 0 ... 15 {
            colors.append(palette[i] ?? NSColor.gray)
        }
        return colors
    }
}

enum GhosttyThemeLoader {
    static let themesDirectory = "/Applications/Ghostty.app/Contents/Resources/ghostty/themes"

    static func availableThemes() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: themesDirectory) else {
            return []
        }
        return entries.sorted()
    }

    static func load(named name: String) -> GhosttyTheme? {
        let path = "\(themesDirectory)/\(name)"
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return parse(contents)
    }

    static func parse(_ contents: String) -> GhosttyTheme {
        var theme = GhosttyTheme()

        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            if key == "palette" {
                // Format: "palette = N=#rrggbb"
                let paletteParts = value.split(separator: "=", maxSplits: 1)
                if paletteParts.count == 2,
                   let index = Int(paletteParts[0].trimmingCharacters(in: .whitespaces)),
                   let color = parseHex(String(paletteParts[1].trimmingCharacters(in: .whitespaces))) {
                    theme.palette[index] = color
                }
            } else if key == "background", let color = parseHex(value) {
                theme.background = color
            } else if key == "foreground", let color = parseHex(value) {
                theme.foreground = color
            } else if key == "cursor-color", let color = parseHex(value) {
                theme.cursorColor = color
            } else if key == "selection-background", let color = parseHex(value) {
                theme.selectionBackground = color
            } else if key == "selection-foreground", let color = parseHex(value) {
                theme.selectionForeground = color
            }
        }

        return theme
    }

    private static func parseHex(_ hex: String) -> NSColor? {
        var str = hex
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let val = UInt64(str, radix: 16) else { return nil }

        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
