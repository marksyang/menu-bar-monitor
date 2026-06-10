import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreference()
    
    var body: some View {
        Form {
            Section("Display") {
                Picker("Display Mode", selection: $preferences.currentMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
        }
        .onDisappear {
            preferences.save()
        }
        .task {
            preferences.load()
        }
    }
}
