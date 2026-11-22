import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject var model: CommitViewModel
    @AppStorage("ollamaLanguage") private var language = "English"
    @AppStorage("changeListHeightPercent") private var panelHeightPercent = 60.0
    @AppStorage("suppressOverwriteConfirmation") private var suppressOverwriteConfirmation = false
    @Environment(\.dismiss) private var dismissPopover
    @StateObject private var ui = MenuBarUIState()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.repositoryURL?.lastPathComponent ?? t("No repository selected", "Kein Repository ausgewählt"))
                        .font(.headline).lineLimit(1)
                    HStack(spacing: 5) {
                        Button {
                            ui.branchSearch = ""
                            ui.showBranchPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                Text(model.snapshot?.branch ?? t("Branch", "Branch")).lineLimit(1)
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .help(t("Switch branch", "Branch wechseln"))
                        .disabled(model.repositoryURL == nil || model.isWorking)
                        .popover(isPresented: $ui.showBranchPicker, arrowEdge: .bottom) {
                            branchPicker
                        }
                        Text("·")
                        Text(changeCountSummary).lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(action: chooseRepository) { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.borderless).help(t("Choose repository", "Repository auswählen"))
                Button(action: refreshRepository) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help(t("Refresh status", "Status aktualisieren"))
            }

            Divider()

            CommitComposer(message: commitMessageBinding, isWorking: model.isWorking,
                           hasChanges: model.hasStagedChanges,
                           canUseAI: model.repositoryURL != nil) {
                if model.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await model.generateMessage() }
                } else {
                    confirmMessageReplacement()
                }
            }

            ChangeSummaryView(files: model.snapshot?.changedFiles ?? [], selectedFileIDs: model.selectedFileIDs,
                              isExpanded: $ui.showChangedFiles, language: language, isDisabled: model.isWorking,
                              onToggle: model.toggleFileSelection, onSelectAll: model.selectAllFiles,
                              onDeselectAll: model.deselectAllFiles,
                              onStageSelected: { Task { await model.stageSelectedFiles() } },
                              onUnstageSelected: { Task { await model.unstageSelectedFiles() } })
                .frame(maxHeight: .infinity, alignment: .top)

            StatusMessages(status: model.statusMessage, error: model.errorMessage)

            Button(action: confirmAndCommit) {
                if model.isWorking { ProgressView().controlSize(.small).frame(maxWidth: .infinity) }
                else { Text(t("Commit", "Commit erstellen")).frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canCommit)
            .keyboardShortcut(.return, modifiers: .command)

            HStack {
                Button {
                    dismissPopover()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        SettingsWindowController.shared.showSettings()
                    }
                } label: { Label(t("Settings", "Einstellungen"), systemImage: "gear") }
                    .buttonStyle(.plain)
                Button {
                    dismissPopover()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        HelpWindowController.shared.showHelp()
                    }
                } label: { Label(t("Help", "Hilfe"), systemImage: "questionmark.circle") }
                    .buttonStyle(.plain)
                Spacer()
                Button(t("Quit", "Beenden")) { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 360, height: ui.panelHeight)
        .onAppear {
            ui.updatePanelHeightForCurrentScreen(percent: panelHeightPercent)
            refreshRepository()
        }
        .onChange(of: panelHeightPercent) { value in
            ui.updatePanelHeightForCurrentScreen(percent: value)
        }
        .onChange(of: model.errorMessage) { value in ui.showError = value != nil }
        .fileImporter(isPresented: $ui.showFolderImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await model.selectRepository(url) } }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert("CommitJet", isPresented: $ui.showError, presenting: model.errorMessage) { _ in
            Button("OK") { model.errorMessage = nil }
        } message: { error in Text(error) }
    }

    private func confirmAndCommit() {
        guard model.canCommit else { return }
        guard model.requiresFirstCommitConfirmation else {
            Task { await model.commit() }
            return
        }

        let alert = NSAlert()
        alert.messageText = t("Commit staged changes?", "Vorgemerkte Änderungen committen?")
        alert.informativeText = t(
            "CommitJet will commit the staged changes only. Unstaged changes will remain in your working tree.",
            "CommitJet committet nur die vorgemerkten Änderungen. Nicht vorgemerkte Änderungen bleiben im Arbeitsverzeichnis."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: t("Commit Staged Changes", "Vorgemerkte Änderungen committen"))
        alert.addButton(withTitle: t("Cancel", "Abbrechen"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = t("Don't show again", "Nicht wieder anzeigen")

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            model.suppressFirstCommitConfirmation()
        }
        guard response == .alertFirstButtonReturn else { return }
        Task { await model.commit(confirmedAllChanges: true) }
    }

    private func confirmMessageReplacement() {
        guard !suppressOverwriteConfirmation else {
            Task { await model.generateMessage() }
            return
        }
        let alert = NSAlert()
        alert.messageText = t("Replace commit message?", "Commit-Nachricht ersetzen?")
        alert.informativeText = t("Ollama's suggestion will replace the current message.", "Der Vorschlag von Ollama ersetzt die aktuelle Nachricht.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: t("Generate", "Erstellen"))
        alert.addButton(withTitle: t("Cancel", "Abbrechen"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = t("Don't show again", "Nicht wieder anzeigen")

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on { suppressOverwriteConfirmation = true }
        if response == .alertFirstButtonReturn { Task { await model.generateMessage() } }
    }

    private var commitMessageBinding: Binding<String> {
        Binding(get: { model.commitMessage }, set: { model.commitMessage = $0 })
    }

    private var changeCountSummary: String {
        guard let snapshot = model.snapshot else { return t("Loading status…", "Status wird geladen …") }
        let count = snapshot.changedFileCount
        return language == "German" ? "\(count) geänderte Dateien" : "\(count) changed \(count == 1 ? "file" : "files")"
    }

    private var filteredBranches: [String] {
        let query = ui.branchSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.localBranches }
        return model.localBranches.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var branchPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Switch branch", "Branch wechseln"))
                .font(.headline)
            TextField(t("Search branches", "Branches suchen"), text: $ui.branchSearch)
                .textFieldStyle(.roundedBorder)
            if model.localBranches.isEmpty {
                Text(t("No local branches found.", "Keine lokalen Branches gefunden."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if filteredBranches.isEmpty {
                Text(t("No matching branches.", "Keine passenden Branches gefunden."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredBranches, id: \.self) { branch in
                            Button {
                                ui.showBranchPicker = false
                                Task { await model.switchBranch(to: branch) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: branch == model.snapshot?.branch ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(branch == model.snapshot?.branch ? Color.accentColor : Color.secondary)
                                    Text(branch).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if branch == model.snapshot?.branch {
                                        Text(t("Current", "Aktiv"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isWorking || branch == model.snapshot?.branch)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
            Text(t("Git keeps compatible changes in your working tree and blocks switches that would overwrite them.", "Git übernimmt passende Änderungen im Arbeitsverzeichnis und verhindert Wechsel, die sie überschreiben würden."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 280, height: 330, alignment: .topLeading)
    }

    private func chooseRepository() {
        ui.showFolderImporter = true
    }

    private func refreshRepository() {
        Task { await model.refresh() }
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }
}

@MainActor
private final class MenuBarUIState: ObservableObject {
    @Published var showError = false
    @Published var showFolderImporter = false
    @Published var showChangedFiles = true
    @Published var showBranchPicker = false
    @Published var branchSearch = ""
    @Published var panelHeight: CGFloat = 540

    func updatePanelHeightForCurrentScreen(percent: Double) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let availableHeight = screen?.visibleFrame.height ?? 900
        let requestedHeight = availableHeight * CGFloat(percent / 100)
        panelHeight = min(max(requestedHeight, min(380, availableHeight)), max(min(380, availableHeight), availableHeight - 20))
    }
}

private struct ChangeSummaryView: View {
    @State private var stagedGroupExpanded = true
    @State private var changesGroupExpanded = true
    let files: [ChangedFile]
    let selectedFileIDs: Set<String>
    @Binding var isExpanded: Bool
    let language: String
    let isDisabled: Bool
    let onToggle: (ChangedFile) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onStageSelected: () -> Void
    let onUnstageSelected: () -> Void

    var body: some View {
        if files.isEmpty {
            Text(AppLanguage.text("No changes to commit", "Keine Änderungen zum Committen", language: language)).font(.caption).foregroundStyle(.secondary)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 9) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppLanguage.text("\(selectedFileIDs.count) of \(files.count) selected", "\(selectedFileIDs.count) von \(files.count) ausgewählt", language: language))
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button(AppLanguage.text("All", "Alle", language: language), action: onSelectAll)
                                .buttonStyle(.plain)
                                .disabled(isDisabled)
                            Text("·").foregroundStyle(.tertiary)
                            Button(AppLanguage.text("None", "Keine", language: language), action: onDeselectAll)
                                .buttonStyle(.plain)
                                .disabled(isDisabled)
                        }
                        .font(.caption2)

                        HStack(spacing: 18) {
                            Button(AppLanguage.text("Stage selected", "Auswahl vormerken", language: language), action: onStageSelected)
                                .buttonStyle(.plain)
                                .disabled(isDisabled || selectedFileIDs.isEmpty)
                            Button(AppLanguage.text("Unstage selected", "Vormerkung aufheben", language: language), action: onUnstageSelected)
                                .buttonStyle(.plain)
                                .disabled(isDisabled || selectedFileIDs.isEmpty)
                            Spacer(minLength: 0)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            changeGroup(AppLanguage.text("Staged Changes", "Gestagete Änderungen", language: language),
                                        files: files.filter(\.isStaged), isExpanded: $stagedGroupExpanded)
                            changeGroup(AppLanguage.text("Changes", "Änderungen", language: language),
                                        files: files.filter(\.isUnstaged), isExpanded: $changesGroupExpanded)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: .infinity)
                }
            } label: {
                Label(AppLanguage.text("Files (\(selectedFileIDs.count)/\(files.count))", "Dateien (\(selectedFileIDs.count)/\(files.count))", language: language), systemImage: "doc.on.doc")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func changeGroup(_ title: String, files: [ChangedFile], isExpanded: Binding<Bool>) -> some View {
        if !files.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(files) { file in
                        ChangedFileRow(file: file, language: language,
                                       isSelected: selectedFileIDs.contains(file.id),
                                       isDisabled: isDisabled,
                                       onToggle: { onToggle(file) })
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } label: {
                Text("\(title) (\(files.count))")
                    .font(.caption)
            }
        }
    }
}

private struct ChangedFileRow: View {
    let file: ChangedFile
    let language: String
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityLabel(AppLanguage.text(isSelected ? "Deselect file" : "Select file for staging", isSelected ? "Dateiauswahl aufheben" : "Datei zum Vormerken auswählen", language: language))
            Image(systemName: file.state.symbolName)
                .font(.caption2)
                .foregroundStyle(file.state.tintColor)
                .frame(width: 13)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.displayPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.state.localizedLabel(language: language))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .help(file.displayPath)
    }
}

private struct CommitComposer: View {
    @Binding var message: String
    let isWorking: Bool
    let hasChanges: Bool
    let canUseAI: Bool
    @AppStorage("ollamaLanguage") private var language = "English"
    @FocusState private var isMessageFocused: Bool
    let onGenerate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField(t("Commit message", "Commit-Nachricht"), text: $message, axis: .vertical)
                .lineLimit(2...)
                .fixedSize(horizontal: false, vertical: true)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(nsColor: .textBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(
                            isMessageFocused ? Color.accentColor.opacity(0.8) : Color(nsColor: .separatorColor),
                            lineWidth: isMessageFocused ? 1.5 : 1
                        )
                }
                .focused($isMessageFocused)
                .accessibilityLabel(t("Commit message", "Commit-Nachricht"))
            Button(action: onGenerate) {
                if isWorking { ProgressView().controlSize(.small) }
                else { Image(systemName: "sparkles") }
            }
            .buttonStyle(.bordered)
            .help(t("Generate with Ollama", "Mit Ollama erstellen"))
            .disabled(!canUseAI || isWorking || !hasChanges)
            .accessibilityLabel(t("Generate commit message with Ollama", "Commit-Nachricht mit Ollama erstellen"))
        }
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }
}

private extension FileChangeState {
    func localizedLabel(language: String) -> String {
        let german: String
        switch self {
        case .added: german = "Hinzugefügt"
        case .modified: german = "Geändert"
        case .deleted: german = "Gelöscht"
        case .renamed: german = "Umbenannt"
        case .copied: german = "Kopiert"
        case .conflicted: german = "Konflikt"
        }
        return AppLanguage.text(label, german, language: language)
    }
}

private struct StatusMessages: View {
    let status: String?
    let error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension FileChangeState {
    var tintColor: Color {
        switch self {
        case .added: return .green
        case .modified: return .orange
        case .deleted, .conflicted: return .red
        case .renamed: return .blue
        case .copied: return .purple
        }
    }
}
