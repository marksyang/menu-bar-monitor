import SwiftUI

struct MenuBarView: View {
    let monitorService: SystemMonitorService
    let preferences: UserPreference
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Text(getDisplayText())
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isAlertState ? .red : .primary)
            .onTapGesture {
                openWindow(id: "mainPanel")
            }
    }
    
    // Observe metrics directly from the service
    private var metrics: SystemMetrics {
        monitorService.metrics
    }

    private var isAlertState: Bool {
        metrics.thermalPressure == "Critical" || metrics.memoryPressure == "Critical"
    }

    private func getDisplayText() -> String {
        let m = metrics
        switch preferences.currentMode {
        case .compact:
            return "CPU \(Int(m.cpuUsage))% GPU \(Int(m.gpuUsage))% MEM \(Int(m.memoryUsage))%"
        case .standard:
//            return "CPU \(Int(m.cpuUsage))% | MEM \(Int(m.memoryUsage))% | \(Int(m.cpuTemperature))°C"
            return "\(Int(m.cpuTemperature))°C   "
//            return "\(String(format: "%.1f°C", monitorService.metrics.cpuTemperature))"
        case .aiMode:
            return "CPU \(Int(m.cpuUsage))% GPU \(Int(m.gpuUsage))% MEM \(Int(m.memoryUsage))% MP:\(m.memoryPressure.prefix(1)) SW \(Int(m.swapUsage))MB TH:\(m.thermalPressure.prefix(1)) F0:\(m.fan0Rpm) F1:\(m.fan1Rpm)"
        case .iconMode:
            return "📊"
        }
    }
}
