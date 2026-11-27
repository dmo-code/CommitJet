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

    func createBranch(at url: URL, named branch: String) throws {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let name = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitError.command("Gib einen Branch-Namen ein.") }
        let validation = try run(["check-ref-format", "--branch", name], at: root)
        guard validation.status == 0 else { throw GitError.command("Der Branch-Name ist ungültig.") }
        let result = try run(["switch", "-c", name], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func deleteBranch(at url: URL, named branch: String) throws {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let currentBranch = try run(["branch", "--show-current"], at: root)
        guard currentBranch.status == 0 else { throw GitError.command(errorText(currentBranch)) }
        let currentName = String(decoding: currentBranch.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard branch != currentName else { throw GitError.command("Der aktive Branch kann nicht gelöscht werden.") }
        let result = try run(["branch", "-d", "--", branch], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func remoteSyncStatus(at url: URL) throws -> RemoteSyncStatus {
        let root = try repositoryRoot(for: url)
        let branchResult = try run(["symbolic-ref", "--quiet", "--short", "HEAD"], at: root)
        guard branchResult.status == 0 else {
            return RemoteSyncStatus(branch: "Detached HEAD", remoteName: nil, upstream: nil, hasCommit: false, aheadCount: 0, behindCount: 0)
        }
        let branch = String(decoding: branchResult.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let headResult = try run(["rev-parse", "--verify", "HEAD"], at: root)
        let hasCommit = headResult.status == 0
        let remoteResult = try run(["remote"], at: root)
        guard remoteResult.status == 0 else { throw GitError.command(errorText(remoteResult)) }
        let remotes = String(decoding: remoteResult.stdout, as: UTF8.self).split(whereSeparator: \.isNewline).map(String.init)

        let upstreamResult = try run(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], at: root)
        guard upstreamResult.status == 0 else {
            return RemoteSyncStatus(branch: branch, remoteName: remotes.first, upstream: nil, hasCommit: hasCommit, aheadCount: 0, behindCount: 0)
        }
        let upstream = String(decoding: upstreamResult.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteName = remotes.first(where: { upstream.hasPrefix($0 + "/") })
        let countResult = try run(["rev-list", "--left-right", "--count", "\(upstream)...HEAD"], at: root)
        guard countResult.status == 0 else { throw GitError.command(errorText(countResult)) }
        let counts = String(decoding: countResult.stdout, as: UTF8.self).split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        guard counts.count == 2 else { throw GitError.command("Der Remote-Status konnte nicht gelesen werden.") }
        return RemoteSyncStatus(branch: branch, remoteName: remoteName, upstream: upstream, hasCommit: hasCommit, aheadCount: counts[1], behindCount: counts[0])
    }

    func push(at url: URL, syncStatus: RemoteSyncStatus) throws {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        guard let remote = syncStatus.remoteName else { throw GitError.command("Für dieses Repository ist kein Remote eingerichtet.") }
        guard syncStatus.hasCommit else { throw GitError.noChanges }
        guard syncStatus.behindCount == 0 else { throw GitError.command("Der lokale Branch liegt hinter dem Remote. Hole die Remote-Änderungen zuerst.") }
        guard syncStatus.aheadCount > 0 || syncStatus.upstream == nil else { return }
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        let arguments = syncStatus.upstream == nil
            ? ["push", "--set-upstream", remote, syncStatus.branch]
            : ["push"]
        let result = try run(arguments, at: root, environment: environment)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    @discardableResult
    func fetchAndFastForward(at url: URL) throws -> Bool {
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)

        let initialStatus = try remoteSyncStatus(at: root)
        guard let remote = initialStatus.remoteName, let upstream = initialStatus.upstream else {
            throw GitError.command("Für diesen Branch ist kein Remote-Tracking-Branch eingerichtet.")
        }

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        let fetch = try run(["fetch", remote], at: root, environment: environment)
        guard fetch.status == 0 else { throw GitError.command(errorText(fetch)) }

        let updatedStatus = try remoteSyncStatus(at: root)
        guard updatedStatus.upstream == upstream else {
            throw GitError.command("Der Upstream dieses Branches hat sich während des Abrufs geändert. Bitte aktualisiere den Status und versuche es erneut.")
        }
        guard updatedStatus.behindCount > 0 else { return false }
        guard updatedStatus.aheadCount == 0 else {
            throw GitError.command("Lokaler Branch und Remote sind auseinander gelaufen. Bitte führe Rebase oder Merge in deinem Git-Client aus.")
        }

        let merge = try run(["merge", "--ff-only", "--no-edit", upstream], at: root)
        guard merge.status == 0 else { throw GitError.command(errorText(merge)) }
        return true
    }

    func commitHistory(at url: URL, branch: String, limit: Int = 100) throws -> CommitHistory {
        let root = try repositoryRoot(for: url)
        let reference = try localBranchReference(branch, at: root)
        let result = try run(["log", "--max-count=\(min(max(limit, 1), 500))", "--format=%H%x00%P%x00%an%x00%aI%x00%s%x00", reference], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
        return CommitHistory(branch: branch, commits: parseCommits(result.stdout))
    }

    func commitDetails(at url: URL, hash: String) throws -> CommitDetails {
        let root = try repositoryRoot(for: url)
        guard hash.count >= 7, hash.allSatisfy(\.isHexDigit) else { throw GitError.command("Ungültige Commit-ID.") }
        let result = try run(["show", "--no-ext-diff", "--no-renames", "--no-color", "--format=%H%x00%P%x00%an%x00%aI%x00%s%x00%b%x00", hash, "--"], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
        let parts = result.stdout.split(separator: 0, maxSplits: 5, omittingEmptySubsequences: false)
        guard parts.count >= 6 else { throw GitError.command("Commit-Details konnten nicht gelesen werden.") }
        let fields = parts.prefix(5).map { String(decoding: $0, as: UTF8.self) }
        let commit = GitCommit(id: fields[0], parents: fields[1].split(whereSeparator: \.isWhitespace).map(String.init), author: fields[2], date: fields[3], subject: fields[4])
        let bodyAndDiff = Data(parts[5])
        let detailEnd = bodyAndDiff.range(of: Data("diff --git ".utf8))?.lowerBound ?? bodyAndDiff.endIndex
        let body = String(decoding: bodyAndDiff[..<detailEnd], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let diff = String(decoding: bodyAndDiff[detailEnd...], as: UTF8.self)
        return CommitDetails(commit: commit, body: body, diff: diff)
    }

    func compareBranches(at url: URL, source: String, target: String) throws -> BranchComparison {
        let root = try repositoryRoot(for: url)
        let sourceRef = try localBranchReference(source, at: root)
        let targetRef = try localBranchReference(target, at: root)
        let counts = try run(["rev-list", "--left-right", "--count", "\(sourceRef)...\(targetRef)"], at: root)
        guard counts.status == 0 else { throw GitError.command(errorText(counts)) }
        let rangeCounts = String(decoding: counts.stdout, as: UTF8.self).split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        guard rangeCounts.count == 2 else { throw GitError.command("Branch-Vergleich konnte nicht gelesen werden.") }
        let sourceOnly = try commits(in: "\(targetRef)..\(sourceRef)", at: root)
        let targetOnly = try commits(in: "\(sourceRef)..\(targetRef)", at: root)
        let paths = try run(["diff", "--name-only", "-z", "--no-renames", "\(targetRef)...\(sourceRef)"], at: root)
        guard paths.status == 0 else { throw GitError.command(errorText(paths)) }
        let changedPaths = paths.stdout.split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
        return BranchComparison(source: source, target: target, sourceOnlyCount: rangeCounts[0], targetOnlyCount: rangeCounts[1], sourceOnly: sourceOnly, targetOnly: targetOnly, changedPaths: changedPaths)
    }

    private func commits(in revisionRange: String, at root: URL) throws -> [GitCommit] {
        let result = try run(["log", "--max-count=200", "--format=%H%x00%P%x00%an%x00%aI%x00%s%x00", revisionRange], at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
        return parseCommits(result.stdout)
    }

    private func parseCommits(_ data: Data) -> [GitCommit] {
        let fields = data.split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        guard fields.count >= 5 else { return [] }
        return stride(from: 0, through: fields.count - 5, by: 5).compactMap { index in
            let hash = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hash.isEmpty else { return nil }
            return GitCommit(id: hash, parents: fields[index + 1].split(whereSeparator: \.isWhitespace).map(String.init), author: fields[index + 2], date: fields[index + 3], subject: fields[index + 4].trimmingCharacters(in: .newlines))
        }
    }

    private func localBranchReference(_ branch: String, at root: URL) throws -> String {
        guard !branch.isEmpty, !branch.contains("\n") else { throw GitError.command("Branch-Name ist ungültig.") }
        let reference = "refs/heads/\(branch)"
        let result = try run(["rev-parse", "--verify", "--quiet", "\(reference)^{commit}"], at: root)
        guard result.status == 0 else { throw GitError.command("Der lokale Branch \(branch) konnte nicht gefunden werden.") }
        return reference
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
        let filesToStage = files.filter(\.isUnstaged)
        guard !filesToStage.isEmpty else { return }
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let result = try run(["add", "-A", "--"] + pathspecs(for: filesToStage), at: root)
        guard result.status == 0 else { throw GitError.command(errorText(result)) }
    }

    func unstage(at url: URL, files: [ChangedFile]) throws {
        let filesToUnstage = files.filter(\.isStaged)
        guard !filesToUnstage.isEmpty else { return }
        let root = try repositoryRoot(for: url)
        try validateOperationState(at: root)
        let paths = pathspecs(for: filesToUnstage)
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
