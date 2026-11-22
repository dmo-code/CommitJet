import XCTest
@testable import CommitJet

final class GitServiceTests: XCTestCase {
    private var root: URL!
    private let git = GitService()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CommitJetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try command(["init", "-q"])
        try command(["config", "user.name", "CommitJet Tests"])
        try command(["config", "user.email", "tests@example.invalid"])
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testRecognizesRepositoryAndStatus() throws {
        XCTAssertEqual(try git.repositoryRoot(for: root), root.standardizedFileURL)
        try "one".write(to: root.appendingPathComponent("space name.txt"), atomically: true, encoding: .utf8)
        let snapshot = try git.snapshot(at: root)
        XCTAssertTrue(snapshot.hasChanges)
        XCTAssertEqual(snapshot.changedFileCount, 1)
        XCTAssertEqual(snapshot.changedFiles.first?.path, "space name.txt")
        XCTAssertEqual(snapshot.changedFiles.first?.state, .added)
    }

    func testRejectsNonRepository() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        XCTAssertThrowsError(try git.repositoryRoot(for: outside))
    }

    func testEmptyRepositoryHasNoChanges() throws {
        let snapshot = try git.snapshot(at: root)
        XCTAssertFalse(snapshot.hasChanges)
        XCTAssertEqual(snapshot.changedFileCount, 0)
    }

    func testCommitAndEmptyRepository() throws {
        try "first".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try git.commit(at: root, message: "", expectedFingerprint: nil))
        try git.commit(at: root, message: "feat: initial commit", expectedFingerprint: nil)
        let snapshot = try git.snapshot(at: root)
        XCTAssertFalse(snapshot.hasChanges)
        XCTAssertNotEqual(snapshot.branch, "Detached HEAD")
    }

    func testReportsRenamedFile() throws {
        try "contents\n".write(to: root.appendingPathComponent("before.txt"), atomically: true, encoding: .utf8)
        try git.commit(at: root, message: "docs: add source file", expectedFingerprint: nil)
        try command(["mv", "before.txt", "after.txt"])
        let snapshot = try git.snapshot(at: root)
        XCTAssertEqual(snapshot.changedFileCount, 1)
        XCTAssertEqual(snapshot.changedFiles.first?.state, .renamed)
        XCTAssertEqual(snapshot.changedFiles.first?.displayPath, "before.txt → after.txt")
    }

    func testRespectsGitignore() throws {
        try "*.ignored\n".write(to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        try git.commit(at: root, message: "chore: add ignore rule", expectedFingerprint: nil)
        try "private\n".write(to: root.appendingPathComponent("secret.ignored"), atomically: true, encoding: .utf8)
        XCTAssertFalse(try git.snapshot(at: root).hasChanges)
    }

    func testRefusesNestedRepositoryAsSubmodule() throws {
        try command(["init", "-q", "nested"])
        XCTAssertThrowsError(try git.prepareDiff(at: root)) { error in
            guard case GitService.GitError.changedSubmodule = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testDetectsMergeConflict() throws {
        try "base\n".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try command(["add", "file.txt"]); try command(["commit", "-qm", "base"])
        let defaultBranch = try commandOutput(["symbolic-ref", "--short", "HEAD"])
        try command(["checkout", "-qb", "other"])
        try "other\n".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try command(["commit", "-qam", "other"])
        try command(["checkout", "-q", defaultBranch])
        try "main\n".write(to: root.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try command(["commit", "-qam", "main"])
        XCTAssertThrowsError(try command(["merge", "other"]))
        let status = try git.snapshot(at: root)
        XCTAssertTrue(status.hasMergeConflicts)
        XCTAssertThrowsError(try git.commit(at: root, message: "bad", expectedFingerprint: nil))
    }

    private func commandOutput(_ args: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/git"); process.arguments = args; process.currentDirectoryURL = root
        let output = Pipe(); process.standardOutput = output; process.standardError = Pipe(); try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "GitTest", code: Int(process.terminationStatus)) }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func command(_ args: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/git"); process.arguments = args; process.currentDirectoryURL = root
        process.standardOutput = Pipe(); process.standardError = Pipe(); try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "GitTest", code: Int(process.terminationStatus)) }
    }
}
