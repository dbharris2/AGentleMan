import SwiftUI

struct SettingsView: View {
    let terminalManager: TerminalManager

    @AppStorage("terminalTheme") private var selectedTheme = "Catppuccin Mocha"
    @State private var searchText = ""
    @State private var allThemes: [String] = []
    @State private var listSelection: String?

    private var filteredThemes: [String] {
        if searchText.isEmpty { return allThemes }
        return allThemes.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal Theme")
                .font(.headline)

            TextField("Search themes...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(filteredThemes, id: \.self, selection: $listSelection) { theme in
                themeRow(theme)
                    .tag(theme)
            }
            .listStyle(.inset)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(20)
        .frame(width: 450, height: 500)
        .onChange(of: listSelection) {
            if let theme = listSelection {
                selectedTheme = theme
            }
        }
        .onChange(of: selectedTheme) {
            terminalManager.themeName = selectedTheme
        }
        .onAppear {
            allThemes = GhosttyThemeLoader.availableThemes()
            listSelection = selectedTheme
            terminalManager.themeName = selectedTheme
        }
    }

    private func themeRow(_ theme: String) -> some View {
        HStack {
            ThemePreview(themeName: theme)
            Text(theme)
            Spacer()
            if theme == selectedTheme {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 1)
    }
}

struct ThemePreview: View {
    let themeName: String

    var body: some View {
        HStack(spacing: 1) {
            if let theme = GhosttyThemeLoader.load(named: themeName) {
                colorSwatch(theme.background, bordered: true)
                colorSwatch(theme.foreground)
                ForEach([1, 2, 4, 5], id: \.self) { idx in
                    if let color = theme.palette[idx] {
                        colorSwatch(color)
                    }
                }
            }
        }
    }

    private func colorSwatch(_ color: NSColor, bordered: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(nsColor: color))
            .frame(width: 14, height: 14)
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
                }
            }
    }
}
