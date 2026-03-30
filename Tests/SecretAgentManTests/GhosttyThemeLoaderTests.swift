@testable import SecretAgentMan
import Testing

struct GhosttyThemeLoaderTests {
    @Test
    func parsesBackgroundAndForeground() {
        let theme = GhosttyThemeLoader.parse("""
        background = #1e1e2e
        foreground = #cdd6f4
        """)
        #expect(theme.background != .black)
        #expect(theme.foreground != .white)
    }

    @Test
    func parsesPaletteEntries() {
        let theme = GhosttyThemeLoader.parse("""
        palette = 0=#45475a
        palette = 1=#f38ba8
        palette = 15=#a6adc8
        """)
        #expect(theme.palette.count == 3)
        #expect(theme.palette[0] != nil)
        #expect(theme.palette[1] != nil)
        #expect(theme.palette[15] != nil)
    }

    @Test
    func parsesCursorAndSelectionColors() {
        let theme = GhosttyThemeLoader.parse("""
        cursor-color = #f5e0dc
        selection-background = #585b70
        selection-foreground = #cdd6f4
        """)
        #expect(theme.cursorColor != .white)
        #expect(theme.selectionBackground != .gray)
        #expect(theme.selectionForeground != .white)
    }

    @Test
    func ignoresCommentsAndBlankLines() {
        let theme = GhosttyThemeLoader.parse("""
        # This is a comment
        background = #000000

        # Another comment
        foreground = #ffffff
        """)
        #expect(theme.palette.isEmpty)
    }

    @Test
    func handlesMissingFields() {
        let theme = GhosttyThemeLoader.parse("background = #1e1e2e")
        #expect(theme.background != .black)
        // Defaults should remain
        #expect(theme.foreground == .white)
        #expect(theme.cursorColor == .white)
    }

    @Test
    func handlesInvalidHex() {
        let theme = GhosttyThemeLoader.parse("""
        background = notahex
        foreground = #zzzzzz
        """)
        // Should keep defaults when hex is invalid
        #expect(theme.background == .black)
        #expect(theme.foreground == .white)
    }

    @Test
    func handlesHexWithoutHash() {
        let theme = GhosttyThemeLoader.parse("background = 1e1e2e")
        #expect(theme.background != .black)
    }

    @Test
    func ignoresMalformedLines() {
        let theme = GhosttyThemeLoader.parse("""
        no equals sign here
        = no key
        background = #1e1e2e
        """)
        #expect(theme.background != .black)
    }

    @Test
    func swiftTermColorsReturns16Entries() {
        let theme = GhosttyThemeLoader.parse("""
        palette = 0=#000000
        palette = 7=#ffffff
        """)
        let colors = theme.swiftTermColors
        #expect(colors.count == 16)
    }
}
