import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @AppStorage("ollamaServer") private var server = "http://localhost:11434"
    @AppStorage("ollamaModel") private var selectedModel = ""
    @AppStorage("ollamaLanguage") private var language = "English"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("commitMessageLength") private var commitMessageLength = "long"
    @AppStorage("ollamaRequestTimeoutSeconds") private var ollamaRequestTimeoutSeconds = 120
    @AppStorage("changeListHeightPercent") private var panelHeightPercent = 60.0
    @StateObject private var ui = SettingsUIState()
    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var loginItemMessage: String?
    @State private var confirmationsRestored = false
    @State private var updateInfo: UpdateService.Release?
    @State private var updateMessage: String?
    @State private var checkingForUpdates = false
    @State private var downloadingUpdate = false
    @State private var downloadProgress: Double?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var updateAvailable: Bool {
        guard let updateInfo else { return false }
        return UpdateService.isNewer(updateInfo.version, than: appVersion)
    }

    private var isNonLocal: Bool {
        guard let host = URLComponents(string: server)?.host?.lowercased() else { return false }
        return host != "localhost" && host != "127.0.0.1" && host != "::1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Form {
                Section(t("General", "Allgemein")) {
                    LabeledContent(t("Version", "Version"), value: appVersion)
                    Button(t("Check for Updates", "Nach Updates suchen")) {
                        Task { await checkForUpdates() }
                    }
                    .disabled(checkingForUpdates || downloadingUpdate)
                    if checkingForUpdates {
                        Text(t("Checking for updates…", "Suche nach Updates …"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else if downloadingUpdate {
                        VStack(alignment: .leading, spacing: 5) {
                            if let downloadProgress {
                                ProgressView(value: downloadProgress)
                                Text(t("Downloading update: \(Int(downloadProgress * 100))%", "Update wird geladen: \(Int(downloadProgress * 100)) %"))
                            } else {
                                ProgressView()
                                Text(t("Downloading update…", "Update wird geladen …"))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else if let updateMessage {
                        Text(updateMessage)
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if updateAvailable, let updateInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(t("Version \(updateInfo.version) available", "Version \(updateInfo.version) verfügbar"), systemImage: "arrow.down.circle.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Link(t("Release notes", "Versionshinweise"), destination: updateInfo.releaseURL)
                                    .font(.caption)
                            }
                            if !updateInfo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                ScrollView {
                                    Text(.init(updateInfo.notes))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 90)
                            }
                            Button {
                                Task { await downloadUpdate(updateInfo) }
                            } label: {
                                Label(t("Download and verify update", "Update laden und prüfen"), systemImage: "arrow.down.to.line")
                            }
                            .disabled(downloadingUpdate || checkingForUpdates)
                            Text(t("The ZIP is checked against its published SHA-256 checksum before it is saved.", "Das ZIP wird vor dem Speichern mit der veröffentlichten SHA-256-Prüfsumme abgeglichen."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    Picker(t("Appearance", "Erscheinungsbild"), selection: $appearance) {
                        Text(t("System", "System")).tag("system")
                        Text(t("Light", "Hell")).tag("light")
                        Text(t("Dark", "Dunkel")).tag("dark")
                    }
                    Toggle(t("Launch at login", "Beim Anmelden starten"), isOn: Binding(
                        get: { loginItemStatus == .enabled || loginItemStatus == .requiresApproval },
                        set: { setLaunchAtLogin($0) }
                    ))
                    Text(t("CommitJet starts automatically when you sign in to your Mac.", "CommitJet startet automatisch, wenn du dich am Mac anmeldest."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if loginItemStatus == .requiresApproval {
                        Text(t("Allow CommitJet in System Settings under General → Login Items.", "Erlaube CommitJet in den Systemeinstellungen unter Allgemein → Anmeldeobjekte."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let loginItemMessage {
                        Text(loginItemMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Section(t("Commit panel", "Commit-Panel")) {
                    Text(t("Panel height", "Panelhöhe"))
                    HStack(spacing: 10) {
                        Slider(value: $panelHeightPercent, in: 45...85, step: 1)
                            .accessibilityLabel(t("Panel height percentage", "Prozentuale Panelhöhe"))
                        TextField(t("Percent", "Prozent"), value: $panelHeightPercent,
                                  format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                    Text(t("Sets the full panel height as a percentage of the usable display height. The file list uses the available space and scrolls when needed.", "Legt die gesamte Panelhöhe als Anteil der nutzbaren Monitorhöhe fest. Die Dateiliste nutzt den verfügbaren Platz und scrollt bei Bedarf."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section(t("Ollama", "Ollama")) {
                    TextField(t("Server address", "Serveradresse"), text: $server)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)
                    Picker(t("Interface and commit language", "Oberflächen- und Commit-Sprache"), selection: $language) {
                        Text("English").tag("English")
                        Text("German").tag("German")
                    }
                    .padding(.vertical, 4)
                    Picker(t("Commit message length", "Länge der Commit-Nachricht"), selection: $commitMessageLength) {
                        Text(t("Short", "Kurz")).tag("short")
                        Text(t("Normal", "Normal")).tag("long")
                        Text(t("Detailed", "Ausführlich")).tag("detailed")
                    }
                    .padding(.vertical, 4)
                    Text(commitMessageLengthDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(t("Response timeout", "Wartezeit für Antwort"))
                        Spacer()
                        TextField("", value: $ollamaRequestTimeoutSeconds,
                                  format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 76)
                            .accessibilityLabel(t("Response timeout in seconds", "Wartezeit in Sekunden"))
                        Text(t("seconds", "Sekunden"))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    .padding(.vertical, 4)
                    Text(t("Maximum wait for a generated response. Defaults to 120 seconds; choose 45 to 600 seconds.", "Maximale Wartezeit für eine generierte Antwort. Standard: 120 Sekunden; einstellbar von 45 bis 600 Sekunden."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Picker(t("Model", "Modell"), selection: $selectedModel) {
                            if ui.models.isEmpty && !selectedModel.isEmpty { Text(selectedModel).tag(selectedModel) }
                            ForEach(ui.models, id: \.self) { Text($0).tag($0) }
                        }
                        Button(t("Load Models", "Modelle laden")) { Task { await loadModels() } }.disabled(ui.working)
                    }
                    .padding(.vertical, 4)
                    Button(t("Test Connection", "Verbindung testen")) { Task { await testConnection() } }.disabled(ui.working)
                        .padding(.vertical, 4)
                    if let message = ui.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    if isNonLocal {
                        Label(t("This server is not on this Mac. Repository diffs are sent to the configured address only when you request an AI message.", "Dieser Server läuft nicht auf diesem Mac. Repository-Diffs werden nur dann an die konfigurierte Adresse gesendet, wenn du eine KI-Nachricht anforderst."), systemImage: "exclamationmark.shield")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section(t("Confirmations", "Bestätigungen")) {
                    Button(t("Show confirmations again", "Bestätigungen wieder anzeigen")) {
                        resetHiddenConfirmations()
                        confirmationsRestored = true
                    }
                    Text(t("Restores dismissed overwrite and first-commit confirmations.", "Blendet ausgeblendete Ersetzungs- und Erst-Commit-Bestätigungen wieder ein."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if confirmationsRestored {
                        Label(t("Confirmations will be shown again.", "Bestätigungen werden wieder angezeigt."), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Privacy", "Datenschutz"))
                    .font(.headline)
                Text(t("CommitJet uses no cloud services or telemetry. Git data is not sent automatically. When you request an AI message, the staged diff goes to the configured Ollama server. When you synchronize, local commits are pushed to the configured Git remote.", "CommitJet verwendet keine Cloud-Dienste und keine Telemetrie. Git-Daten werden nicht automatisch übertragen. Wenn du eine KI-Nachricht anforderst, wird der gestagte Diff an den eingestellten Ollama-Server gesendet. Beim Synchronisieren werden lokale Commits zum eingerichteten Git-Remote übertragen."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(width: 560)
        .background(.regularMaterial)
        .preferredColorScheme(preferredColorScheme)
        .task {
            refreshLoginItemStatus()
            await checkForUpdates(silent: true)
            await loadModels(silent: true)
        }
        .onChange(of: language) { value in
            SettingsWindowController.shared.updateTitle(language: value)
            HelpWindowController.shared.updateTitle(language: value)
        }
        .onAppear {
            let clampedValue = min(max(panelHeightPercent.rounded(), 45), 85)
            if panelHeightPercent != clampedValue { panelHeightPercent = clampedValue }
            ollamaRequestTimeoutSeconds = min(max(ollamaRequestTimeoutSeconds, 45), 600)
        }
        .onChange(of: panelHeightPercent) { value in
            let clampedValue = min(max(value.rounded(), 45), 85)
            if value != clampedValue { panelHeightPercent = clampedValue }
        }
        .onChange(of: ollamaRequestTimeoutSeconds) { value in
            let clampedValue = min(max(value, 45), 600)
            if value != clampedValue { ollamaRequestTimeoutSeconds = clampedValue }
        }
    }

    private func loadModels(silent: Bool = false) async {
        ui.working = true
        defer { ui.working = false }
        do {
            ui.models = try await OllamaService().models(server: server)
            if !ui.models.contains(selectedModel) { selectedModel = ui.models.first ?? "" }
            let count = ui.models.count
            ui.message = t("Found \(count) model(s).", "\(count) \(count == 1 ? "Modell" : "Modelle") gefunden.")
        } catch { if !silent { ui.message = error.localizedDescription } }
    }

    private func testConnection() async {
        ui.working = true
        defer { ui.working = false }
        do { try await OllamaService().test(server: server); ui.message = t("Connection successful.", "Verbindung erfolgreich.") }
        catch { ui.message = error.localizedDescription }
    }

    private func checkForUpdates(silent: Bool = false) async {
        checkingForUpdates = true
        defer { checkingForUpdates = false }
        do {
            updateInfo = try await UpdateService().latestRelease()
            if updateAvailable {
                updateMessage = nil
            } else {
                updateMessage = t("You’re up to date.", "Du verwendest die aktuelle Version.")
            }
        } catch {
            if !silent {
                updateMessage = t("Could not check for updates: \(error.localizedDescription)", "Updates konnten nicht gesucht werden: \(error.localizedDescription)")
            }
        }
    }

    private func downloadUpdate(_ release: UpdateService.Release) async {
        downloadingUpdate = true
        downloadProgress = nil
        defer { downloadingUpdate = false }
        do {
            let fileURL = try await UpdateService().download(release) { progress in
                downloadProgress = progress
            }
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            updateMessage = t("Update downloaded and verified. Open the ZIP and move CommitJet.app to Applications to replace the current version.", "Update geladen und geprüft. Öffne das ZIP und verschiebe CommitJet.app in Programme, um die vorhandene Version zu ersetzen.")
        } catch {
            updateMessage = t("Could not download update: \(error.localizedDescription)", "Update konnte nicht geladen werden: \(error.localizedDescription)")
        }
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }

    private var commitMessageLengthDescription: String {
        switch commitMessageLength {
        case "short":
            t("Short: subject only. Keep it concise without cutting off the description.", "Kurz: nur der Betreff. Knapp formuliert, ohne die Beschreibung abzuschneiden.")
        case "detailed":
            t("Detailed: add the relevant context and effects supported by the changes.", "Ausführlich: ergänze belegbaren Kontext und die Auswirkungen der Änderungen.")
        default:
            t("Normal: add a brief explanation when it provides useful context.", "Normal: ergänze eine kurze Erklärung, wenn sie nützlichen Kontext bietet.")
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private func resetHiddenConfirmations() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "suppressOverwriteConfirmation")
        defaults.set(false, forKey: "suppressFirstCommitConfirmation")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("confirmedAllChanges:") {
            defaults.removeObject(forKey: key)
        }
    }

    private func refreshLoginItemStatus() {
        loginItemStatus = SMAppService.mainApp.status
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginItemMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginItemStatus()
        } catch {
            refreshLoginItemStatus()
            loginItemMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class SettingsUIState: ObservableObject {
    @Published var models: [String] = []
    @Published var message: String?
    @Published var working = false
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func showSettings() {
        if let window, window.isVisible {
            bringToFront(window)
            return
        }
        window = nil
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.isOpaque = false
        settingsWindow.backgroundColor = .windowBackgroundColor
        settingsWindow.titlebarAppearsTransparent = false
        settingsWindow.title = AppLanguage.text("CommitJet Settings", "CommitJet-Einstellungen", language: UserDefaults.standard.string(forKey: "ollamaLanguage") ?? "English")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.collectionBehavior.insert(.moveToActiveSpace)
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        window = settingsWindow
        bringToFront(settingsWindow)
    }

    func updateTitle(language: String) {
        window?.title = AppLanguage.text("CommitJet Settings", "CommitJet-Einstellungen", language: language)
    }

    private func bringToFront(_ window: NSWindow) {
        window.collectionBehavior.insert(.moveToActiveSpace)
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HelpView: View {
    @AppStorage("ollamaLanguage") private var language = "English"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("Using CommitJet", "CommitJet verwenden"))
                    .font(.title2.bold())

                section(
                    "Choose a repository", "Repository auswählen",
                    "Select a local Git repository from the folder button. CommitJet shows its current branch and changed files. Select the files to include; new changes are selected automatically.",
                    "Wähle über die Ordnerschaltfläche ein lokales Git-Repository aus. CommitJet zeigt den aktuellen Branch und die geänderten Dateien. Wähle die Dateien für den Commit aus; neue Änderungen sind automatisch ausgewählt."
                )
                section(
                    "Switch branches", "Branches wechseln",
                    "Select the current branch name to search and switch between local branches. Git keeps compatible working-tree changes and blocks switches that would overwrite them.",
                    "Klicke auf den aktuellen Branchnamen, um lokale Branches zu durchsuchen und zu wechseln. Git übernimmt passende Änderungen im Arbeitsverzeichnis und verhindert Wechsel, die sie überschreiben würden."
                )
                section(
                    "Create and review a message", "Nachricht erstellen und prüfen",
                    "Select Sparkles to ask Ollama for a suggestion. Choose the language and level of detail in Settings. You can edit the message before committing. If a message is already present, CommitJet asks before replacing it.",
                    "Klicke auf Funkeln, um Ollama um einen Vorschlag zu bitten. Sprache und Detailgrad legst du in den Einstellungen fest. Du kannst die Nachricht vor dem Commit bearbeiten. Wenn bereits eine Nachricht vorhanden ist, fragt CommitJet vor dem Ersetzen."
                )
                section(
                    "Create a commit", "Commit erstellen",
                    "Select files and use Stage selected or Unstage selected to manage the Git staging area. Commit creates a local commit from staged changes only. Use Sync changes to push local commits to a configured remote. If your branch is behind its remote, pull those changes with your Git client before pushing.",
                    "Wähle Dateien aus und nutze Auswahl vormerken oder Vormerkung aufheben, um den Git-Stage zu verwalten. Commit erstellen übernimmt ausschließlich gestagete Änderungen. Über Änderungen synchronisieren pushst du lokale Commits zu einem eingerichteten Remote. Liegt dein Branch hinter dem Remote, hole die Änderungen vor dem Push mit deinem Git-Client."
                )
                section(
                    "Ollama and privacy", "Ollama und Datenschutz",
                    "AI suggestions are optional. Repository diffs are sent to the configured Ollama server only when you request a suggestion. If the server is remote, its operator can receive that diff. CommitJet uses no telemetry or cloud service.",
                    "KI-Vorschläge sind optional. Repository-Diffs werden nur dann an den eingestellten Ollama-Server gesendet, wenn du einen Vorschlag anforderst. Bei einem externen Server kann dessen Betreiber den Diff erhalten. CommitJet verwendet weder Telemetrie noch einen Cloud-Dienst."
                )
                section(
                    "Show confirmations again", "Bestätigungen wieder anzeigen",
                    "If you selected Don't show again for a prompt, open Settings and select Show confirmations again. This restores message replacement and first-commit confirmations.",
                    "Wenn du bei einer Abfrage Nicht wieder anzeigen gewählt hast, öffne die Einstellungen und klicke auf Bestätigungen wieder anzeigen. Dadurch werden Bestätigungen zum Ersetzen der Commit-Nachricht und für den ersten Commit wieder eingeblendet."
                )
                section(
                    "Launch at login", "Beim Anmelden starten",
                    "Enable Launch at login in Settings to start CommitJet when you sign in to your Mac. macOS may ask you to allow it under General → Login Items.",
                    "Aktiviere Beim Anmelden starten in den Einstellungen, damit CommitJet beim Anmelden am Mac startet. macOS bittet dich eventuell, die App unter Allgemein → Anmeldeobjekte zu erlauben."
                )
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 560, height: 560)
        .background(.regularMaterial)
    }

    private func section(_ englishTitle: String, _ germanTitle: String, _ englishText: String, _ germanText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t(englishTitle, germanTitle))
                .font(.headline)
            Text(t(englishText, germanText))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }
}

@MainActor
final class HelpWindowController {
    static let shared = HelpWindowController()
    private var window: NSWindow?

    func showHelp() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        helpWindow.title = AppLanguage.text("CommitJet Help", "CommitJet-Hilfe", language: UserDefaults.standard.string(forKey: "ollamaLanguage") ?? "English")
        helpWindow.isReleasedWhenClosed = false
        helpWindow.contentView = NSHostingView(rootView: HelpView())
        helpWindow.center()
        window = helpWindow
        NSApp.activate(ignoringOtherApps: true)
        helpWindow.makeKeyAndOrderFront(nil)
    }

    func updateTitle(language: String) {
        window?.title = AppLanguage.text("CommitJet Help", "CommitJet-Hilfe", language: language)
    }
}
