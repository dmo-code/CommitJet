import Foundation
import Combine

@MainActor
final class CommitViewModel: ObservableObject {
    @Published private(set) var repositoryURL: URL?
    @Published private(set) var snapshot: RepositorySnapshot?
    @Published var commitMessage = ""
    @Published private(set) var isWorking = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var requiresFirstCommitConfirmation = false
    private var aiFingerprint: String?
    private let git = GitService()
    private let preferences = UserDefaults.standard

    init() {
        if let path = preferences.string(forKey: "repositoryPath") {
            repositoryURL = URL(fileURLWithPath: path, isDirectory: true)
            Task { await refresh() }
        }
    }

    var canCommit: Bool { snapshot?.hasChanges == true && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking }

    func selectRepository(_ url: URL) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let root = try await Task.detached { try self.git.repositoryRoot(for: url) }.value
            repositoryURL = root
            preferences.set(root.path, forKey: "repositoryPath")
            snapshot = try await Task.detached { try self.git.snapshot(at: root) }.value
            aiFingerprint = nil
            statusMessage = nil
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        guard let repositoryURL else { return }
        isWorking = true
        defer { isWorking = false }
        do { snapshot = try await Task.detached { try self.git.snapshot(at: repositoryURL) }.value }
        catch { errorMessage = error.localizedDescription }
    }

    func generateMessage() async {
        guard let repositoryURL else { return }
        isWorking = true
        statusMessage = localized("Generating commit message…", "Commit-Nachricht wird erstellt …")
        defer { isWorking = false }
        do {
            let diff = try await Task.detached { try self.git.prepareDiff(at: repositoryURL) }.value
            let server = preferences.string(forKey: "ollamaServer") ?? "http://localhost:11434"
            let model = preferences.string(forKey: "ollamaModel") ?? ""
            let language = preferences.string(forKey: "ollamaLanguage") ?? "English"
            let messageLength = preferences.string(forKey: "commitMessageLength") ?? "long"
            guard !model.isEmpty else { throw OllamaService.OllamaError.noModels }
            let answer = try await OllamaService().generate(server: server, model: model, diff: diff.text, language: language, detail: messageLength)
            commitMessage = answer
            aiFingerprint = diff.fingerprint
            statusMessage = localized("AI message ready to review", "KI-Nachricht kann geprüft werden")
        } catch { errorMessage = error.localizedDescription; statusMessage = nil }
    }

    func commit(confirmedAllChanges: Bool = false) async {
        guard canCommit, let repositoryURL else { return }
        if requiresConfirmation {
            guard confirmedAllChanges else { requiresFirstCommitConfirmation = true; return }
            acknowledgeFirstCommit()
        }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }
        let message = commitMessage
        let fingerprint = aiFingerprint
        do {
            try await Task.detached { try self.git.commit(at: repositoryURL, message: message, expectedFingerprint: fingerprint) }.value
            aiFingerprint = nil
            commitMessage = ""
            statusMessage = localized("Commit created", "Commit erstellt")
            snapshot = try await Task.detached { try self.git.snapshot(at: repositoryURL) }.value
        } catch { errorMessage = error.localizedDescription }
    }

    func acknowledgeFirstCommit() { preferences.set(true, forKey: acknowledgementKey) }
    func dismissFirstCommitConfirmation() { requiresFirstCommitConfirmation = false }

    private var acknowledgementKey: String { "confirmedAllChanges:" + (repositoryURL?.path ?? "") }
    private var requiresConfirmation: Bool { !preferences.bool(forKey: acknowledgementKey) }

    private func localized(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: preferences.string(forKey: "ollamaLanguage") ?? "English")
    }
}
