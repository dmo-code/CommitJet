import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("ollamaServer") private var server = "http://localhost:11434"
    @AppStorage("ollamaModel") private var selectedModel = ""
    @AppStorage("ollamaLanguage") private var language = "English"
    @AppStorage("commitMessageLength") private var commitMessageLength = "long"
    @StateObject private var ui = SettingsUIState()

    private var isNonLocal: Bool {
        guard let host = URLComponents(string: server)?.host?.lowercased() else { return false }
        return host != "localhost" && host != "127.0.0.1" && host != "::1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Form {
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
                        Text(t("Long", "Lang")).tag("long")
                        Text(t("Detailed", "Ausführlich")).tag("detailed")
                    }
                    .padding(.vertical, 4)
                    Text(t("Subject: max. 72 characters; body lines: max. 72 characters.", "Betreff: höchstens 72 Zeichen; Textzeilen: höchstens 72 Zeichen."))
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
                    }
                    Text(t("Restores dismissed overwrite and first-commit confirmations.", "Blendet ausgeblendete Ersetzungs- und Erst-Commit-Bestätigungen wieder ein."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Privacy", "Datenschutz"))
                    .font(.headline)
                Text(t("CommitJet does not use cloud services or telemetry. Git data is sent only to Ollama after you click the Sparkles button.", "CommitJet verwendet keine Cloud-Dienste und keine Telemetrie. Git-Daten werden erst nach einem Klick auf die Funkeln-Schaltfläche an Ollama gesendet."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(width: 560)
        .background(.regularMaterial)
        .task { await loadModels(silent: true) }
        .onChange(of: language) { value in
            SettingsWindowController.shared.updateTitle(language: value)
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

    private func t(_ english: String, _ german: String) -> String {
        AppLanguage.text(english, german, language: language)
    }

    private func resetHiddenConfirmations() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "suppressOverwriteConfirmation")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("confirmedAllChanges:") {
            defaults.removeObject(forKey: key)
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
        if let window {
            bringToFront(window)
            return
        }
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
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        window = settingsWindow
        bringToFront(settingsWindow)
    }

    func updateTitle(language: String) {
        window?.title = AppLanguage.text("CommitJet Settings", "CommitJet-Einstellungen", language: language)
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}
