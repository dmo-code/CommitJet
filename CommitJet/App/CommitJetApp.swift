import SwiftUI
import AppKit

@main
struct CommitJetApp: App {
    @StateObject private var model = CommitViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(nsImage: CommitJetMark.image)
                .renderingMode(.template)
                .accessibilityLabel("CommitJet")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
private enum CommitJetMark {
    static let image: NSImage = {
        guard let url = Bundle.main.url(forResource: "airplane-departure-variant", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "airplane", accessibilityDescription: "CommitJet")!
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}
