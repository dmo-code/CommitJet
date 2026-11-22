import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject var model: CommitViewModel
    @AppStorage("ollamaLanguage") private var language = "English"
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
                    Text(repositorySummary)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: chooseRepository) { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.borderless).help(t("Choose repository", "Repository auswählen"))
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help(t("Refresh status", "Status aktualisieren"))
            }

            Divider()

            CommitComposer(message: commitMessageBinding, isWorking: model.isWorking,
                           hasChanges: model.snapshot?.hasChanges == true,
                           canUseAI: model.repositoryURL != nil) {
                if model.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await model.generateMessage() }
                } else {
                    ui.showOverwriteWarning = true
                }
            }

            ChangeSummaryView(files: model.snapshot?.changedFiles ?? [], isExpanded: $ui.showChangedFiles, language: language)

            StatusMessages(status: model.statusMessage, error: model.errorMessage)

            Button { Task { await model.commit() } } label: {
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
                Spacer()
                Button(t("Quit", "Beenden")) { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 360)
        .onChange(of: model.errorMessage) { value in ui.showError = value != nil }
        .fileImporter(isPresented: $ui.showFolderImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await model.selectRepository(url) } }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(confirmationTitle, isPresented: confirmationBinding, titleVisibility: .visible) {
            if model.requiresFirstCommitConfirmation {
                Button(t("Cancel", "Abbrechen"), role: .cancel) {}
                Button(t("Include All Changes", "Alle Änderungen einbeziehen"), role: .destructive) {
                    model.acknowledgeFirstCommit()
                    model.dismissFirstCommitConfirmation()
                    Task { await model.commit() }
                }
            } else {
                Button(t("Cancel", "Abbrechen"), role: .cancel) {}
                Button(t("Generate", "Erstellen")) { ui.showOverwriteWarning = false; Task { await model.generateMessage() } }
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert("CommitJet", isPresented: $ui.showError, presenting: model.errorMessage) { _ in
            Button("OK") { model.errorMessage = nil }
        } message: { error in Text(error) }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { model.requiresFirstCommitConfirmation || ui.showOverwriteWarning },
            set: { isPresented in
                if !isPresented {
                    model.dismissFirstCommitConfirmation()
                    ui.showOverwriteWarning = false
                }
            }
        )
    }

    private var confirmationTitle: String {
        model.requiresFirstCommitConfirmation ? t("Include all repository changes?", "Alle Repository-Änderungen einbeziehen?") : t("Replace commit message?", "Commit-Nachricht ersetzen?")
    }

    private var confirmationMessage: String {
        model.requiresFirstCommitConfirmation
            ? t("CommitJet will include all non-ignored changes in this repository, including staged and new files. Review the count above before continuing.", "CommitJet bezieht alle nicht ignorierten Änderungen in diesem Repository ein, einschließlich vorgemerkter und neuer Dateien. Prüfe oben die Anzahl, bevor du fortfährst.")
            : t("Ollama's suggestion will replace the current message.", "Der Vorschlag von Ollama ersetzt die aktuelle Nachricht.")
    }

    private var commitMessageBinding: Binding<String> {
        Binding(get: { model.commitMessage }, set: { model.commitMessage = $0 })
    }

    private var repositorySummary: String {
        guard let snapshot = model.snapshot else { return t("Choose a local Git repository", "Lokales Git-Repository auswählen") }
        let count = snapshot.changedFileCount
        return language == "German" ? "\(snapshot.branch) · \(count) geänderte Dateien" : "\(snapshot.branch) · \(count) changed \(count == 1 ? "file" : "files")"
    }

    private func chooseRepository() {
        ui.showFolderImporter = true
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }
}

@MainActor
private final class MenuBarUIState: ObservableObject {
    @Published var showOverwriteWarning = false
    @Published var showError = false
    @Published var showFolderImporter = false
    @Published var showChangedFiles = true
}

private struct ChangeSummaryView: View {
    let files: [ChangedFile]
    @Binding var isExpanded: Bool
    let language: String

    var body: some View {
        if files.isEmpty {
            Text(AppLanguage.text("No changes to commit", "Keine Änderungen zum Committen", language: language)).font(.caption).foregroundStyle(.secondary)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(files) { file in
                            ChangedFileRow(file: file, language: language)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 150)
            } label: {
                Label(AppLanguage.text("Changed files (\(files.count))", "Geänderte Dateien (\(files.count))", language: language), systemImage: "doc.on.doc")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ChangedFileRow: View {
    let file: ChangedFile
    let language: String

    var body: some View {
        HStack(spacing: 7) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(file.state.localizedLabel(language: language)): \(file.displayPath)")
    }
}

private struct CommitComposer: View {
    @Binding var message: String
    let isWorking: Bool
    let hasChanges: Bool
    let canUseAI: Bool
    @AppStorage("ollamaLanguage") private var language = "English"
    let onGenerate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField(t("Commit message", "Commit-Nachricht"), text: $message, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
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
