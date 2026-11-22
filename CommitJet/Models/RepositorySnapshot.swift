import Foundation

enum FileChangeState: String, Equatable, Sendable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case conflicted

    var symbolName: String {
        switch self {
        case .added: return "plus"
        case .modified: return "pencil"
        case .deleted: return "minus"
        case .renamed: return "arrow.left.arrow.right"
        case .copied: return "doc.on.doc"
        case .conflicted: return "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .conflicted: return "Conflict"
        }
    }
}

struct ChangedFile: Identifiable, Equatable, Sendable {
    let path: String
    let oldPath: String?
    let state: FileChangeState
    let isStaged: Bool
    let isUnstaged: Bool

    var id: String { (oldPath ?? "") + "\u{0}" + path }
    var displayPath: String { oldPath.map { "\($0) → \(path)" } ?? path }
}

struct RepositorySnapshot: Equatable, Sendable {
    let rootURL: URL
    let branch: String
    let changedFiles: [ChangedFile]
    let hasMergeConflicts: Bool
    let containsChangedSubmodule: Bool

    var changedFileCount: Int { changedFiles.count }
    var hasChanges: Bool { !changedFiles.isEmpty }
}

struct RemoteSyncStatus: Equatable, Sendable {
    let branch: String
    let remoteName: String?
    let upstream: String?
    let hasCommit: Bool
    let aheadCount: Int
    let behindCount: Int

    var hasRemote: Bool { remoteName != nil }
}

struct PreparedDiff: Sendable {
    let text: String
    let fingerprint: String
}
