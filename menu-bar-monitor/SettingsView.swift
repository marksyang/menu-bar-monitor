import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreference()
    
    var body: some View {
        Form {
            Section("Display Configuration") {
                Picker("Display Mode", selection: $preferences.currentMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: preferences.currentMode) {
                    preferences.save()
                }
            }
            
            Section("Startup") {
                Toggle("Launch at Login", isOn: $preferences.startupLaunch)
                    .onChange(of: preferences.startupLaunch) {
                        preferences.save()
                    }
            }
        }
        .padding()
        .onAppear {
            preferences.load()
        }
    }
}
