import Foundation
import Combine

@MainActor
final class CommitViewModel: ObservableObject {
    @Published private(set) var repositoryURL: URL?
    @Published private(set) var snapshot: RepositorySnapshot?
    @Published private(set) var localBranches: [String] = []
    @Published private(set) var remoteSyncStatus: RemoteSyncStatus?
    @Published private(set) var selectedFileIDs: Set<String> = []
    @Published var commitMessage = ""
    @Published private(set) var isWorking = false
    @Published private(set) var isCommitting = false
    @Published private(set) var isSynchronizing = false
    @Published private(set) var isPulling = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    private var aiFingerprint: String?
    private let git = GitService()
    private let preferences = UserDefaults.standard

    init() {
        if let path = preferences.string(forKey: "repositoryPath") {
            repositoryURL = URL(fileURLWithPath: path, isDirectory: true)
            Task { await refresh() }
        }
    }

    var selectedFiles: [ChangedFile] { snapshot?.changedFiles.filter { selectedFileIDs.contains($0.id) } ?? [] }
    var hasSelectedChanges: Bool { !selectedFiles.isEmpty }
    var hasStagedChanges: Bool { snapshot?.changedFiles.contains(where: \.isStaged) == true }
    var canCommit: Bool { hasStagedChanges && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking }

    func selectRepository(_ url: URL) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let root = try await Task.detached { try self.git.repositoryRoot(for: url) }.value
            if repositoryURL != root {
                selectedFileIDs = []
                knownFileIDs = []
            }
            repositoryURL = root
            preferences.set(root.path, forKey: "repositoryPath")
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: root), branches: try self.git.localBranches(at: root), sync: try self.git.remoteSyncStatus(at: root))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
            aiFingerprint = nil
            statusMessage = nil
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        guard let repositoryURL else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), branches: try self.git.localBranches(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
        }
        catch { errorMessage = error.localizedDescription }
    }

    func switchBranch(to branch: String) async {
        guard let repositoryURL, branch != snapshot?.branch else { return }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }
        do {
            try await Task.detached { try self.git.switchBranch(at: repositoryURL, to: branch) }.value
            if aiFingerprint != nil {
                commitMessage = ""
                aiFingerprint = nil
            }
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), branches: try self.git.localBranches(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
            statusMessage = localized("Switched to \(branch)", "Zu \(branch) gewechselt")
        } catch { errorMessage = error.localizedDescription }
    }

    func createBranch(named branch: String) async {
        guard let repositoryURL, !isWorking else { return }
        isWorking = true
        statusMessage = nil
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await Task.detached { try self.git.createBranch(at: repositoryURL, named: branch) }.value
            if aiFingerprint != nil {
                commitMessage = ""
                aiFingerprint = nil
            }
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), branches: try self.git.localBranches(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
            statusMessage = localized("Created and switched to \(branch)", "Branch \(branch) erstellt und gewechselt")
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBranch(named branch: String) async {
        guard let repositoryURL, !isWorking, branch != snapshot?.branch else { return }
        isWorking = true
        statusMessage = nil
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await Task.detached { try self.git.deleteBranch(at: repositoryURL, named: branch) }.value
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), branches: try self.git.localBranches(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
            statusMessage = localized("Deleted branch \(branch)", "Branch \(branch) gelöscht")
        } catch { errorMessage = error.localizedDescription }
    }

    func generateMessage() async {
        guard let repositoryURL else { return }
        guard hasStagedChanges else { return }
        isWorking = true
        statusMessage = localized("Generating commit message…", "Commit-Nachricht wird erstellt …")
        defer { isWorking = false }
        do {
            let diff = try await Task.detached { try self.git.prepareStagedDiff(at: repositoryURL) }.value
            let server = preferences.string(forKey: "ollamaServer") ?? "http://localhost:11434"
            let model = preferences.string(forKey: "ollamaModel") ?? ""
            let language = preferences.string(forKey: "ollamaLanguage") ?? "English"
            let messageLength = preferences.string(forKey: "commitMessageLength") ?? "long"
            let timeout = min(max(preferences.object(forKey: "ollamaRequestTimeoutSeconds") as? Int ?? 120, 45), 600)
            guard !model.isEmpty else { throw OllamaService.OllamaError.noModels }
            let answer = try await OllamaService().generate(server: server, model: model, diff: diff.text, language: language, detail: messageLength, timeout: TimeInterval(timeout))
            commitMessage = answer
            aiFingerprint = diff.fingerprint
            let repositoryName = repositoryURL.lastPathComponent
            let notificationLanguage = preferences.string(forKey: "ollamaLanguage") ?? "English"
            let notificationMessage = answer.components(separatedBy: .newlines).first ?? answer
            Task {
                await NotificationService.notifyCommitMessageReady(
                    repositoryName: repositoryName,
                    message: notificationMessage,
                    language: notificationLanguage
                )
            }
            let lengthLabel: (String, String)
            switch messageLength {
            case "short": lengthLabel = ("Short", "Kurz")
            case "detailed": lengthLabel = ("Detailed", "Ausführlich")
            default: lengthLabel = ("Normal", "Normal")
            }
            statusMessage = localized("AI message ready to review · \(lengthLabel.0)", "KI-Nachricht kann geprüft werden · \(lengthLabel.1)")
        } catch { errorMessage = error.localizedDescription; statusMessage = nil }
    }

    func commit(confirmedAllChanges: Bool = false) async {
        guard canCommit, let repositoryURL else { return }
        if requiresConfirmation {
            guard confirmedAllChanges else { return }
            acknowledgeFirstCommit()
        }
        isWorking = true
        isCommitting = true
        statusMessage = nil
        defer { isWorking = false }
        defer { isCommitting = false }
        let message = commitMessage
        let fingerprint = aiFingerprint
        let files = snapshot?.changedFiles ?? []
        do {
            try await Task.detached { try self.git.commit(at: repositoryURL, message: message, files: files, expectedFingerprint: fingerprint) }.value
            aiFingerprint = nil
            commitMessage = ""
            statusMessage = localized("Commit created", "Commit erstellt")
            let refreshed = try await Task.detached { try self.git.snapshot(at: repositoryURL) }.value
            snapshot = refreshed
            updateSelection(for: refreshed)
            remoteSyncStatus = try await Task.detached { try self.git.remoteSyncStatus(at: repositoryURL) }.value
        } catch { errorMessage = error.localizedDescription }
    }

    func synchronizeChanges() async {
        guard let repositoryURL, let currentStatus = remoteSyncStatus,
              currentStatus.hasRemote, currentStatus.behindCount == 0,
              currentStatus.aheadCount > 0 || currentStatus.upstream == nil else { return }
        isWorking = true
        isSynchronizing = true
        statusMessage = nil
        errorMessage = nil
        defer { isWorking = false }
        defer { isSynchronizing = false }
        do {
            try await Task.detached { try self.git.push(at: repositoryURL, syncStatus: currentStatus) }.value
            remoteSyncStatus = try await Task.detached { try self.git.remoteSyncStatus(at: repositoryURL) }.value
            statusMessage = localized("Changes pushed to remote", "Änderungen zum Remote übertragen")
        } catch { errorMessage = error.localizedDescription }
    }

    func pullRemoteChanges() async {
        guard let repositoryURL, let currentStatus = remoteSyncStatus,
              currentStatus.hasRemote, currentStatus.upstream != nil,
              !isWorking else { return }
        isWorking = true
        isPulling = true
        statusMessage = nil
        errorMessage = nil
        defer { isWorking = false }
        defer { isPulling = false }
        do {
            let didPull = try await Task.detached { try self.git.fetchAndFastForward(at: repositoryURL) }.value
            let result = try await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), branches: try self.git.localBranches(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            snapshot = result.snapshot
            updateSelection(for: result.snapshot)
            localBranches = result.branches
            remoteSyncStatus = result.sync
            if didPull {
                invalidateGeneratedMessageIfNeeded()
                statusMessage = localized("Remote changes pulled", "Remote-Änderungen geholt")
            } else {
                statusMessage = localized("Remote checked; no changes to pull", "Remote geprüft; keine Änderungen abzurufen")
            }
        } catch {
            errorMessage = error.localizedDescription
            let refreshed = try? await Task.detached {
                (snapshot: try self.git.snapshot(at: repositoryURL), sync: try self.git.remoteSyncStatus(at: repositoryURL))
            }.value
            if let refreshed {
                snapshot = refreshed.snapshot
                remoteSyncStatus = refreshed.sync
                updateSelection(for: refreshed.snapshot)
            }
        }
    }

    func toggleFileSelection(_ file: ChangedFile) {
        if selectedFileIDs.contains(file.id) { selectedFileIDs.remove(file.id) }
        else { selectedFileIDs.insert(file.id) }
        invalidateGeneratedMessageIfNeeded()
    }

    func selectAllFiles() {
        selectedFileIDs = Set(snapshot?.changedFiles.map(\.id) ?? [])
        invalidateGeneratedMessageIfNeeded()
    }

    func deselectAllFiles() {
        selectedFileIDs.removeAll()
        invalidateGeneratedMessageIfNeeded()
    }

    func stageSelectedFiles() async { await updateStaging(stage: true) }
    func unstageSelectedFiles() async { await updateStaging(stage: false) }

    private func updateStaging(stage: Bool) async {
        guard let repositoryURL, !selectedFiles.isEmpty else { return }
        let files = selectedFiles
        isWorking = true
        statusMessage = nil
        errorMessage = nil
        defer { isWorking = false }
        do {
            if stage {
                try await Task.detached { try self.git.stage(at: repositoryURL, files: files) }.value
            } else {
                try await Task.detached { try self.git.unstage(at: repositoryURL, files: files) }.value
            }
            invalidateGeneratedMessageIfNeeded()
            let refreshed = try await Task.detached { try self.git.snapshot(at: repositoryURL) }.value
            snapshot = refreshed
            updateSelection(for: refreshed)
            statusMessage = stage
                ? localized("Selected files staged", "Ausgewählte Dateien vorgemerkt")
                : localized("Selected files unstaged", "Vormerkung ausgewählter Dateien aufgehoben")
        } catch { errorMessage = error.localizedDescription }
    }

    func acknowledgeFirstCommit() { preferences.set(true, forKey: acknowledgementKey) }
    func suppressFirstCommitConfirmation() { preferences.set(true, forKey: "suppressFirstCommitConfirmation") }

    private var acknowledgementKey: String { "confirmedAllChanges:" + (repositoryURL?.path ?? "") }
    var requiresFirstCommitConfirmation: Bool {
        !preferences.bool(forKey: "suppressFirstCommitConfirmation") && !preferences.bool(forKey: acknowledgementKey)
    }

    private var requiresConfirmation: Bool { requiresFirstCommitConfirmation }

    private var knownFileIDs: Set<String> = []

    private func updateSelection(for snapshot: RepositorySnapshot) {
        let currentIDs = Set(snapshot.changedFiles.map(\.id))
        let previousSelection = selectedFileIDs
        selectedFileIDs.formIntersection(currentIDs)
        selectedFileIDs.formUnion(currentIDs.subtracting(knownFileIDs))
        knownFileIDs = currentIDs
        if previousSelection != selectedFileIDs { invalidateGeneratedMessageIfNeeded() }
    }

    private func invalidateGeneratedMessageIfNeeded() {
        guard aiFingerprint != nil else { return }
        aiFingerprint = nil
        commitMessage = ""
    }

    private func localized(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: preferences.string(forKey: "ollamaLanguage") ?? "English")
    }
}
