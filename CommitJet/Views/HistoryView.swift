import SwiftUI
import AppKit

@MainActor
private final class HistoryViewModel: ObservableObject {
    @Published private(set) var repositoryURL: URL?
    @Published private(set) var branches: [String] = []
    @Published private(set) var history: CommitHistory?
    @Published private(set) var comparison: BranchComparison?
    @Published private(set) var details: CommitDetails?
    @Published private(set) var selectedCommitID: String?
    @Published private(set) var sourceBranch = ""
    @Published private(set) var targetBranch = ""
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private let git = GitService()

    func show(repository: URL, branch: String) {
        repositoryURL = repository
        sourceBranch = branch
        Task { await load() }
    }

    func load() async {
        guard let repositoryURL else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let branch = sourceBranch
            let git = self.git
            let result = try await Task.detached {
                (branches: try git.localBranches(at: repositoryURL), history: try git.commitHistory(at: repositoryURL, branch: branch))
            }.value
            branches = result.branches
            history = result.history
            if !branches.contains(sourceBranch) { sourceBranch = branches.first ?? "" }
            if targetBranch.isEmpty || !branches.contains(targetBranch) {
                targetBranch = branches.first(where: { $0 != sourceBranch }) ?? ""
            }
            if let first = history?.commits.first { await selectCommit(first) }
            else { details = nil; selectedCommitID = nil }
            await loadComparison()
        } catch { self.error = error.localizedDescription }
    }

    func selectHistoryBranch(_ branch: String) async {
        guard !branch.isEmpty else { return }
        sourceBranch = branch
        history = nil
        details = nil
        selectedCommitID = nil
        guard let repositoryURL else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await Task.detached { try self.git.commitHistory(at: repositoryURL, branch: branch) }.value
            history = result
            if let first = result.commits.first { await selectCommit(first) }
        } catch { self.error = error.localizedDescription }
    }

    func selectComparisonBranches(source: String? = nil, target: String? = nil) async {
        if let source { sourceBranch = source }
        if let target { targetBranch = target }
        await loadComparison()
    }

    func loadComparison() async {
        guard let repositoryURL, !sourceBranch.isEmpty, !targetBranch.isEmpty, sourceBranch != targetBranch else {
            comparison = nil
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        let source = sourceBranch
        let target = targetBranch
        let git = self.git
        do { comparison = try await Task.detached { try git.compareBranches(at: repositoryURL, source: source, target: target) }.value }
        catch { self.error = error.localizedDescription }
    }

    func selectCommit(_ commit: GitCommit) async {
        selectedCommitID = commit.id
        guard let repositoryURL else { return }
        do { details = try await Task.detached { try self.git.commitDetails(at: repositoryURL, hash: commit.id) }.value }
        catch { self.error = error.localizedDescription }
    }
}

struct HistoryView: View {
    @AppStorage("ollamaLanguage") private var language = "English"
    @StateObject private var model = HistoryViewModel()
    @State private var showingComparison = false
    @State private var showingTextSizePicker = false
    @AppStorage("historyTextScale") private var textScale = 1.0
    @AppStorage("historySidebarWidth") private var sidebarWidth = 380.0
    let repositoryURL: URL
    let initialBranch: String

    init(repository: URL, branch: String) {
        repositoryURL = repository
        initialBranch = branch
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("History", "Verlauf")).font(.title2.bold())
                    Text(repositoryURL.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    modeButton(t("Commit history", "Commit-Verlauf"), selected: !showingComparison) {
                        showingComparison = false
                    }
                    modeButton(t("Branch comparison", "Branch-Vergleich"), selected: showingComparison) {
                        showingComparison = true
                    }
                }
                .frame(width: 300)
                Button { showingTextSizePicker.toggle() } label: { Image(systemName: "textformat.size") }
                    .buttonStyle(.borderless)
                    .help(t("Adjust text size", "Textgröße einstellen"))
                    .accessibilityLabel(t("Adjust text size", "Textgröße einstellen"))
                    .popover(isPresented: $showingTextSizePicker, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(t("Text size", "Textgröße")).font(.headline)
                                Spacer()
                                Text("\(Int((textScale * 100).rounded())) %")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $textScale, in: 0.8...1.6, step: 0.1)
                            HStack {
                                Text(t("Smaller", "Kleiner"))
                                Spacer()
                                Text(t("Larger", "Größer"))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(t("Use ⌘+ and ⌘− to adjust, or ⌘0 to reset.", "Mit ⌘+ und ⌘− änderst du die Größe; ⌘0 setzt sie zurück."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack {
                                Spacer()
                                Button(t("Reset", "Zurücksetzen")) { textScale = 1.0 }
                            }
                        }
                        .padding(14)
                        .frame(width: 250)
                    }
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help(t("Refresh history", "Verlauf aktualisieren"))
                    .disabled(model.isLoading)
            }
            .padding(16)
            Divider()
            if let error = model.error {
                Text(error).font(.callout).foregroundStyle(.red).padding()
            }
            if showingComparison { compareContent } else { historyContent }
        }
        .frame(minWidth: 760, minHeight: 520)
        .background(.regularMaterial)
        .onAppear { model.show(repository: repositoryURL, branch: initialBranch) }
        .overlay {
            HStack(spacing: 0) {
                Button(t("Increase text size", "Text vergrößern")) { textScale = min(1.6, textScale + 0.1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button(t("Decrease text size", "Text verkleinern")) { textScale = max(0.8, textScale - 0.1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button(t("Reset text size", "Textgröße zurücksetzen")) { textScale = 1.0 }
                    .keyboardShortcut("0", modifiers: .command)
                Button(t("Close history", "Verlauf schließen")) { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.cancelAction)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private var historyContent: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("Branch", "Branch")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.isLoading { ProgressView().controlSize(.small) }
                }
                Picker(t("Branch", "Branch"), selection: Binding(get: { model.sourceBranch }, set: { branch in Task { await model.selectHistoryBranch(branch) } })) {
                    ForEach(model.branches, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                List(model.history?.commits ?? [], selection: Binding(get: { model.selectedCommitID }, set: { id in
                    guard let commit = model.history?.commits.first(where: { $0.id == id }) else { return }
                    Task { await model.selectCommit(commit) }
                })) { commit in
                    CommitRow(commit: commit, textScale: textScale)
                        .tag(Optional(commit.id))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.sidebar)
                .overlay {
                    if !model.isLoading && (model.history?.commits.isEmpty ?? true) {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2).foregroundStyle(.tertiary)
                    Text(t("No commits found", "Keine Commits gefunden")).foregroundStyle(.secondary)
                }
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: CGFloat(sidebarWidth), maxHeight: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: HistorySidebarWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            commitDetail
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(HistorySidebarWidthPreferenceKey.self) { width in
            guard width >= 280, abs(sidebarWidth - Double(width)) > 1 else { return }
            sidebarWidth = Double(width)
        }
    }

    private var commitDetail: some View {
        ScrollView {
            if let details = model.details {
                VStack(alignment: .leading, spacing: 14) {
                    Text(details.commit.subject).font(.system(size: 18 * textScale, weight: .bold)).textSelection(.enabled)
                    HStack(spacing: 8) {
                        Label(details.commit.author, systemImage: "person")
                        Text("·")
                        Label(formattedDate(details.commit.date), systemImage: "calendar")
                    }
                    .font(.system(size: 12 * textScale)).foregroundStyle(.secondary)
                    Text(String(details.commit.id.prefix(12)))
                        .font(.system(size: 12 * textScale, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                    if !details.body.isEmpty { Text(details.body).font(.system(size: 14 * textScale)).textSelection(.enabled) }
                    Divider()
                    Text(t("Changes", "Änderungen")).font(.system(size: 16 * textScale, weight: .semibold))
                    if details.diff.isEmpty {
                        Text(t("No file changes in this commit.", "Dieser Commit enthält keine Dateiänderungen."))
                            .font(.system(size: 13 * textScale)).foregroundStyle(.secondary)
                    } else {
                        GitDiffView(diff: details.diff, textScale: textScale)
                    }
                }
                .padding(20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2).foregroundStyle(.tertiary)
                    Text(t("Select a commit", "Commit auswählen")).foregroundStyle(.secondary)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var compareContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                branchPicker(title: t("Changes from", "Änderungen von"), selection: model.sourceBranch) { value in Task { await model.selectComparisonBranches(source: value) } }
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                branchPicker(title: t("Compared with", "Verglichen mit"), selection: model.targetBranch) { value in Task { await model.selectComparisonBranches(target: value) } }
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
            }
            Text(t("File changes use the common ancestor of these branches. Commit lists show commits unique to each branch.", "Dateiänderungen werden ab dem gemeinsamen Vorfahren verglichen. Die Commit-Listen zeigen Commits, die nur auf dem jeweiligen Branch liegen."))
                .font(.system(size: 12 * textScale)).foregroundStyle(.secondary)
            if let comparison = model.comparison {
                HStack(alignment: .top, spacing: 20) {
                    comparisonColumn(title: "\(comparison.source) · \(comparison.sourceOnlyCount)", commits: comparison.sourceOnly)
                    comparisonColumn(title: "\(comparison.target) · \(comparison.targetOnlyCount)", commits: comparison.targetOnly)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("Changed files", "Geänderte Dateien")).font(.headline)
                        if comparison.changedPaths.isEmpty {
                            Text(t("No file changes", "Keine Dateiänderungen")).foregroundStyle(.secondary)
                        } else {
                            List(comparison.changedPaths, id: \.self) { path in
                                Label(path, systemImage: "doc")
                                    .font(.system(size: 12 * textScale, design: .monospaced))
                                    .textSelection(.enabled)
                                    .listRowSeparator(.hidden)
                            }
                            .listStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else if model.sourceBranch == model.targetBranch {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right").font(.title2).foregroundStyle(.tertiary)
                    Text(t("Choose two different branches", "Wähle zwei verschiedene Branches")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func branchPicker(title: String, selection: String, onChange: @escaping @Sendable (String) -> Void) -> some View {
        Picker(title, selection: Binding(get: { selection }, set: onChange)) {
            ForEach(model.branches, id: \.self) { Text($0).tag($0) }
        }
        .frame(maxWidth: 220)
    }

    private func comparisonColumn(title: String, commits: [GitCommit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14 * textScale, weight: .semibold)).lineLimit(1)
            if commits.isEmpty { Text(t("No unique commits", "Keine eigenen Commits")).font(.system(size: 12 * textScale)).foregroundStyle(.secondary) }
            else {
                List(commits) { commit in CommitRow(commit: commit, textScale: textScale).listRowSeparator(.hidden) }
                    .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formattedDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }

    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 32)
                .padding(.horizontal, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

}

private struct HistorySidebarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 380

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GitDiffView: View {
    let diff: String
    let textScale: Double

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(Array(diff.split(separator: "\n").enumerated()), id: \.offset) { _, substring in
                let line = String(substring)
                Text(line)
                    .font(.system(size: 11 * textScale, weight: isFileHeader(line) ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(foreground(for: line))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: line), in: RoundedRectangle(cornerRadius: 3))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func foreground(for line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .blue }
        if line.hasPrefix("diff --git") { return .primary }
        return .secondary
    }

    private func background(for line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green.opacity(0.09) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red.opacity(0.09) }
        if line.hasPrefix("@@") { return .blue.opacity(0.08) }
        return .clear
    }

    private func isFileHeader(_ line: String) -> Bool {
        line.hasPrefix("diff --git") || line.hasPrefix("---") || line.hasPrefix("+++")
    }
}

private struct CommitRow: View {
    let commit: GitCommit
    let textScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commit.subject).font(.system(size: 12 * textScale, weight: .medium)).lineLimit(2)
            HStack(spacing: 5) {
                Text(String(commit.id.prefix(7))).font(.system(size: 10 * textScale, design: .monospaced))
                Text("·")
                Text(commit.author).lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 10 * textScale))
        }
        .padding(.vertical, 3)
    }
}

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()
    private var window: NSWindow?

    func show(repository: URL, branch: String) {
        let view = HistoryView(repository: repository, branch: branch)
        if let window, window.isVisible {
            window.contentView = NSHostingView(rootView: view)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let historyWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 650), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        historyWindow.title = AppLanguage.text("CommitJet History", "CommitJet-Verlauf", language: UserDefaults.standard.string(forKey: "ollamaLanguage") ?? "English")
        historyWindow.minSize = NSSize(width: 760, height: 500)
        historyWindow.isReleasedWhenClosed = false
        historyWindow.collectionBehavior.insert(.moveToActiveSpace)
        historyWindow.contentView = NSHostingView(rootView: view)
        historyWindow.center()
        window = historyWindow
        NSApp.activate(ignoringOtherApps: true)
        historyWindow.makeKeyAndOrderFront(nil)
    }
}
