import Foundation
import SwiftUI

/// Centralized, observable state for all user settings
@Observable
class UserPreference {
    var currentMode: DisplayMode = .standard
    var enabledMetrics: [MonitorMetric] = [.cpuUsage, .gpuUsage, .memoryUsage, .fanRpm, .temperature]
    var alertConditions: [AlertCondition] = []
    var startupLaunch: Bool = false
    
    // UserDefaults persistence stubs
    func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            UserDefaults.standard.set(data, forKey: "MonitorBarPreferences")
        }
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: "MonitorBarPreferences"),
              let decoded = try? JSONDecoder().decode(UserPreference.self, from: data) else { return }
        
        currentMode = decoded.currentMode
        enabledMetrics = decoded.enabledMetrics
        alertConditions = decoded.alertConditions
        startupLaunch = decoded.startupLaunch
    }
}
