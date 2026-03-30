import Foundation

enum MCPConfigLoader {
    static func loadServerNames(in directory: URL) -> [String] {
        let mcpFile = directory.appendingPathComponent(".mcp.json")
        guard let data = try? Data(contentsOf: mcpFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any]
        else { return [] }
        return servers.keys.sorted()
    }

    static func loadPluginNames() -> [String] {
        let pluginsFile = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/plugins/installed_plugins.json")
        guard let data = try? Data(contentsOf: pluginsFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any]
        else { return [] }
        // Keys are "name@marketplace" — extract just the name
        return plugins.keys.map { $0.components(separatedBy: "@").first ?? $0 }.sorted()
    }
}
