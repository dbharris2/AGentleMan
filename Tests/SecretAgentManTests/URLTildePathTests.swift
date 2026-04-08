import Foundation
@testable import SecretAgentMan
import Testing

struct URLTildePathTests {
    @Test
    func stripsTrailingSlash() {
        let url = URL(fileURLWithPath: "/Users/devon/projects/MyApp/", isDirectory: true)
        #expect(!url.tildeAbbreviatedPath.hasSuffix("/"))
    }

    @Test
    func consistentWithAndWithoutTrailingSlash() {
        let withSlash = URL(fileURLWithPath: "/Users/devon/projects/MyApp/", isDirectory: true)
        let withoutSlash = URL(fileURLWithPath: "/Users/devon/projects/MyApp")
        #expect(withSlash.tildeAbbreviatedPath == withoutSlash.tildeAbbreviatedPath)
    }

    @Test
    func standardizedAndRawProduceSameKey() {
        let raw = URL(fileURLWithPath: NSHomeDirectory() + "/dmars/SecretAgentMan")
        let standardized = raw.standardizedFileURL
        #expect(raw.tildeAbbreviatedPath == standardized.tildeAbbreviatedPath)
    }

    @Test
    func replacesHomeDirWithTilde() {
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/projects/MyApp")
        #expect(url.tildeAbbreviatedPath == "~/projects/MyApp")
    }

    @Test
    func preservesRootPath() {
        let url = URL(fileURLWithPath: "/")
        #expect(url.tildeAbbreviatedPath == "/")
    }
}
