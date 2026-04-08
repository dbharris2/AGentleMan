import Foundation

extension URL {
    var tildeAbbreviatedPath: String {
        var p = path
        while p.count > 1, p.hasSuffix("/") {
            p = String(p.dropLast())
        }
        return p.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
