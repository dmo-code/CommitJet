import Foundation
import CryptoKit

struct GitService {
    enum GitError: LocalizedError {
        case notRepository
        case command(String)
        case conflicts
        case operationInProgress(String)
        case changedSubmodule
        case noChanges
        case noFilesSelected
        case changedDuringCommit
        case diffTooLarge
        case missingCommitMessage

        var errorDescription: String? {
            switch self {
            case .notRepository: return "Der ausgewählte Ordner ist kein Git-Repository."
            case .command(let message): return message
            case .conflicts: return "Das Repository enthält nicht aufgelöste Merge-Konflikte. Bitte löse sie zuerst in deinem Git-Client."
            case .operationInProgress(let operation): return "Im Repository läuft eine Git-Operation (\(operation)). Beende sie zuerst."
            case .changedSubmodule: return "Geänderte Submodule werden nicht automatisch übernommen. Bitte committe sie separat."
            case .noChanges: return "Es gibt keine nicht ignorierten Änderungen zum Committen."
            case .noFilesSelected: return "Wähle mindestens eine Datei für den Commit aus."
            case .changedDuringCommit: return "Der Repository-Zustand hat sich seit der Diff-Analyse geändert. Bitte prüfe die Änderungen erneut."
            case .diffTooLarge: return "Der Diff ist zu groß für die lokale KI-Anfrage (maximal 150 KB)."
            case .missingCommitMessage: return "Gib eine Commit-Nachricht ein."
            }
        }
    }

    func repositoryRoot(for url: URL) throws -> URL {
        let result = try run(["rev-parse", "--show-toplevel"], at: url)
        guard result.status == 0, let path = String(data: result.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            throw GitError.notRepository
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    func snapshot(at url: URL) throws -> RepositorySnapshot {
        let root = try repositoryRoot(for: url)
        let branchResult = try run(["symbolic-ref", "--quiet", "--short", "HEAD"], at: root)
        let branch = branchResult.status == 0 ? String(decoding: branchResult.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) : "Detached HEAD"
        let status = try run(["status", "--porcelain=v1", "-z", "--untracked-files=all"], at: root)
        guard status.status == 0 else { throw GitError.command(errorText(status)) }
        let records = statusRecords(status.stdout.split(separator: 0, omittingEmptySubsequences: true))
        let hasConflicts = records.contains { $0.state == .conflicted }
        let hasSubmodule = try changedSubmodule(in: records, at: root)
        let files = records.map { record in
            ChangedFile(path: record.path, oldPath: record.oldPath, state: record.state,
                        isStaged: record.status.first.map { $0 != " " && $0 != "?" } ?? false,
                        isUnstaged: (record.status.dropFirst().first.map { $0 != " " } ?? false) || record.status == "??")
        }
        return RepositorySnapshot(rootURL: root, branch: branch.isEmpty ? "Detached HEAD" : branch, changedFiles: files, hasMergeConflicts: hasConflicts, containsChangedSubmodule: hasSubmodule)
    }

    func localBranches(at url: URL) throws -> [String] {
        let root = try repositoryRoot(for: url)
        let result = try run(["for-each-ref", "--format=%(refname:short)", "refs/heads"], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
        return String(decoding: result.stdout, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    func switchBranch(at url: URL, to branch: String) throws {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let result = try run(["switch", branch], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func prepareDiff(at url: URL, files: [ChangedFile]) throws -> PreparedDiff {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        guard !files.isEmpty else { throw GitError.noFilesSelected }
        return try stagedDiffAtRoot(root)
    }

    func prepareStagedDiff(at url: URL) throws -> PreparedDiff {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        return try stagedDiffAtRoot(root)
    }

    private func stagedDiffAtRoot(_ root: URL) throws -> PreparedDiff {
        let staged = try run(["diff", "--cached", "--binary", "--no-ext-diff", "--no-renames"], at: root)
        guard staged.status == 0 else { throw GitError.command(errorText(staged)) }
        let raw = try run(["diff", "--cached", "--raw", "--no-renames"], at: root)
        guard raw.status == 0 else { throw GitError.command(errorText(raw)) }
        if containsGitlink(raw.stdout) { throw GitError.changedSubmodule }
        guard !staged.stdout.isEmpty else { throw GitError.noChanges }
        guard staged.stdout.count <= 150_000 else { throw GitError.diffTooLarge }
        return PreparedDiff(text: String(decoding: staged.stdout, as: UTF8.self), fingerprint: Self.digest(staged.stdout))
    }

    func prepareDiff(at url: URL) throws -> PreparedDiff {
        try prepareDiff(at: url, files: snapshot(at: url).changedFiles)
    }

    func commit(at url: URL, message: String, files: [ChangedFile], expectedFingerprint: String?) throws {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { throw GitError.missingCommitMessage }
        guard !files.isEmpty else { throw GitError.noFilesSelected }
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let actual = try run(["diff", "--cached", "--binary", "--no-ext-diff", "--no-renames"], at: root)
        guard actual.status == 0 else { throw GitError.command(errorText(actual)) }
        let raw = try run(["diff", "--cached", "--raw", "--no-renames"], at: root)
        guard raw.status == 0 else { throw GitError.command(errorText(raw)) }
        if containsGitlink(raw.stdout) { throw GitError.changedSubmodule }
        guard !actual.stdout.isEmpty else { throw GitError.noChanges }
        if let expectedFingerprint, Self.digest(actual.stdout) != expectedFingerprint { throw GitError.changedDuringCommit }
        let result = try run(["commit", "-m", cleanMessage], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func stage(at url: URL, files: [ChangedFile]) throws {
        guard !files.isEmpty else { throw GitError.noFilesSelected }
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let result = try run(["add", "-A", "--"] + pathspecs(for: files), at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func unstage(at url: URL, files: [ChangedFile]) throws {
        guard !files.isEmpty else { throw GitError.noFilesSelected }
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let paths = pathspecs(for: files)
        let head = try run(["rev-parse", "--verify", "HEAD"], at: root)
        let result = head.status == 0
            ? try run(["reset", "-q", "HEAD", "--"] + paths, at: root)
            : try run(["rm", "--cached", "-r", "--"] + paths, at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func commit(at url: URL, message: String, expectedFingerprint: String?) throws {
        try commit(at: url, message: message, files: snapshot(at: url).changedFiles, expectedFingerprint: expectedFingerprint)
    }

    private func pathspecs(for files: [ChangedFile]) -> [String] {
        let paths = files.flatMap { file -> [String] in
            var paths = [file.path]
            if let oldPath = file.oldPath { paths.append(oldPath) }
            return paths
        }
        return Array(Set(paths)).sorted().map { ":(literal)\($0)" }
    }

    private func validateOperationState(at root: URL) throws {
        let state = try run(["status", "--porcelain=v1", "-z", "--untracked-files=all"], at: root)
        guard state.status == 0 else { throw GitError.command(errorText(state)) }
        let entries = statusRecords(state.stdout.split(separator: 0, omittingEmptySubsequences: true))
        if entries.contains(where: { $0.state == .conflicted }) { throw GitError.conflicts }
        if try changedSubmodule(in: entries, at: root) { throw GitError.changedSubmodule }

        let gitPathResult = try run(["rev-parse", "--git-dir"], at: root)
        guard gitPathResult.status == 0 else { throw GitError.command(errorText(gitPathResult)) }
        let raw = String(decoding: gitPathResult.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDir = URL(fileURLWithPath: raw, relativeTo: root).standardizedFileURL
        let operations: [(String, String)] = [("MERGE_HEAD", "merge"), ("CHERRY_PICK_HEAD", "cherry-pick"), ("REVERT_HEAD", "revert"), ("rebase-merge", "rebase"), ("rebase-apply", "rebase"), ("BISECT_LOG", "bisect")]
        for (path, name) in operations where FileManager.default.fileExists(atPath: gitDir.appendingPathComponent(path).path) {
            throw GitError.operationInProgress(name)
        }
    }

    private struct StatusRecord {
        let status: String
        let path: String
        let oldPath: String?
        let pathBytes: Data
        let oldPathBytes: Data?
        let state: FileChangeState
    }

    private func statusRecords(_ entries: [Data.SubSequence]) -> [StatusRecord] {
        var records: [StatusRecord] = []
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            guard entry.count >= 3 else { index += 1; continue }
            let statusBytes = Data(entry.prefix(2))
            let status = String(decoding: statusBytes, as: UTF8.self)
            let pathBytes = Data(entry.dropFirst(3))
            let source = status.contains("R") || status.contains("C") ? entries.indices.contains(index + 1) ? Data(entries[index + 1]) : nil : nil
            let oldPath = source.map { String(decoding: $0, as: UTF8.self) }
            let state: FileChangeState
            if status.contains("U") || status == "AA" || status == "DD" { state = .conflicted }
            else if status.contains("R") { state = .renamed }
            else if status.contains("C") { state = .copied }
            else if status == "??" || status.contains("A") { state = .added }
            else if status.contains("D") { state = .deleted }
            else { state = .modified }
            records.append(StatusRecord(status: status, path: String(decoding: pathBytes, as: UTF8.self), oldPath: oldPath, pathBytes: pathBytes, oldPathBytes: source, state: state))
            if source != nil { index += 1 }
            index += 1
        }
        return records
    }

    private func containsGitlink(_ rawDiff: Data) -> Bool {
        for line in String(decoding: rawDiff, as: UTF8.self).split(separator: "\n") where line.hasPrefix(":") {
            let fields = line.split(separator: " ")
            if fields.count >= 2 && (fields[0] == "160000" || fields[1] == "160000") { return true }
        }
        return false
    }

    private func changedSubmodule(in statusEntries: [StatusRecord], at root: URL) throws -> Bool {
        let index = try run(["ls-files", "--stage", "-z"], at: root)
        guard index.status == 0 else { throw GitError.command(errorText(index)) }
        var gitlinks = Set<Data>()
        for record in index.stdout.split(separator: 0, omittingEmptySubsequences: true) {
            guard let tab = record.firstIndex(of: 9) else { continue }
            let header = record[..<tab]
            if header.starts(with: Data("160000 ".utf8)) { gitlinks.insert(Data(record[record.index(after: tab)...])) }
        }
        for entry in statusEntries {
            if gitlinks.contains(entry.pathBytes) || entry.oldPathBytes.map(gitlinks.contains) == true { return true }
        }
        return false
    }

    private struct Result { let status: Int32; let stdout: Data; let stderr: Data }

    private func run(_ arguments: [String], at directory: URL, environment: [String: String]? = nil) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        if let environment { process.environment = environment }
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { throw GitError.command("Git konnte nicht gestartet werden: \(error.localizedDescription)") }
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func errorText(_ result: Result) -> String {
        let text = String(decoding: result.stderr.isEmpty ? result.stdout : result.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Git ist mit Status \(result.status) fehlgeschlagen." : text
    }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
