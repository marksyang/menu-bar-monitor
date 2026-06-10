import Foundation

struct AlertCondition: Identifiable, Codable {
    let id = UUID()
    var metric: MonitorMetric
    var threshold: Double
    var action: AlertAction
    
    enum AlertAction: String, CaseIterable, Codable {
        case notification
        case colorChange
        case sound
    }
}
