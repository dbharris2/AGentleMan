import Foundation

struct FileChange: Identifiable, Hashable {
    let id: String
    let path: String
    let insertions: Int
    let deletions: Int
    let status: ChangeStatus

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var directoryPath: String {
        (path as NSString).deletingLastPathComponent
    }

    enum ChangeStatus: String, Hashable {
        case added
        case modified
        case deleted
        case renamed

        var label: String {
            switch self {
            case .added: "A"
            case .modified: "M"
            case .deleted: "D"
            case .renamed: "R"
            }
        }
    }
}
