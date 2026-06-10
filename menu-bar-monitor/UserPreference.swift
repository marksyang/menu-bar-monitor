import Foundation
import SwiftUI

/// Centralized, observable state for all user settings
@Observable
class UserPreference: Codable {
    var currentMode: DisplayMode = .standard
    var enabledMetrics: [MonitorMetric] = [.cpuUsage, .gpuUsage, .memoryUsage, .fanRpm, .temperature]
    var alertConditions: [AlertCondition] = []
    var startupLaunch: Bool = false
    
    /// Explicit parameterless initializer to satisfy `UserPreference()` calls.
    init() {
        // Properties are already initialized with their default values.
    }

    // Explicit CodingKeys & init(from:) override synthesis to prevent the 
    // @Observable macro's generated `let` property from triggering Decodable warnings.
    enum CodingKeys: String, CodingKey {
        case currentMode, enabledMetrics, alertConditions, startupLaunch
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentMode = try container.decode(DisplayMode.self, forKey: .currentMode)
        enabledMetrics = try container.decode([MonitorMetric].self, forKey: .enabledMetrics)
        alertConditions = try container.decode([AlertCondition].self, forKey: .alertConditions)
        startupLaunch = try container.decode(Bool.self, forKey: .startupLaunch)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentMode, forKey: .currentMode)
        try container.encode(enabledMetrics, forKey: .enabledMetrics)
        try container.encode(alertConditions, forKey: .alertConditions)
        try container.encode(startupLaunch, forKey: .startupLaunch)
    }
    
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
