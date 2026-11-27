import Foundation

enum FileChangeState: String, Equatable, Sendable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case conflicted

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

    var shortLabel: String {
        switch self {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .conflicted: return "!"
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
    var filename: String { (path as NSString).lastPathComponent }
    var directoryPath: String? {
        let directory = (path as NSString).deletingLastPathComponent
        return directory.isEmpty || directory == "." ? nil : directory
    }
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

struct GitCommit: Identifiable, Equatable, Sendable {
    let id: String
    let parents: [String]
    let author: String
    let date: String
    let subject: String
}

struct CommitHistory: Sendable {
    let branch: String
    let commits: [GitCommit]
}

struct BranchComparison: Sendable {
    let source: String
    let target: String
    let sourceOnlyCount: Int
    let targetOnlyCount: Int
    let sourceOnly: [GitCommit]
    let targetOnly: [GitCommit]
    let changedPaths: [String]
}

struct CommitDetails: Sendable {
    let commit: GitCommit
    let body: String
    let diff: String
}
