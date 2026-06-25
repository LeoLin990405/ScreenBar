import SwiftUI

struct ScreenBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(systemName: "display.2")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(model: model)
                .frame(width: 640, height: 520)
        }
    }
}
