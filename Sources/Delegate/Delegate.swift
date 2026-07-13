import SwiftUI

@main
struct DelegateApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            DelegatePanel(model: model)
                .frame(width: 380, height: 520)
        } label: {
            Image(systemName: model.isPaused ? "shield.slash.fill" : "checkmark.shield.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 520, height: 360)
        }
    }
}
