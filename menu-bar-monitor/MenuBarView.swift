import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var preferences = UserPreference()
    @State private var metrics = SystemMetrics()

    var body: some View {
        Text(getDisplayText())
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isAlertState ? .red : .primary)
            .onTapGesture {
                openWindow(id: "mainPanel")
            }
    }

    private var isAlertState: Bool {
        metrics.thermalPressure == "Critical" || metrics.memoryPressure == "Critical"
    }

    private func getDisplayText() -> String {
        switch preferences.currentMode {
        case .compact:
            // FR-015: Compact Mode
            return "CPU\(Int(metrics.cpuUsage)} GPU\(Int(metrics.gpuUsage)} MEM\(Int(metrics.memoryUsage)}"
        case .standard:
            // FR-015: Standard Mode
            return "CPU \(Int(metrics.cpuUsage)}% | MEM \(Int(metrics.memoryUsage)}% | \(Int(metrics.temperature)}°C"
        case .aiMode:
            // FR-015: AI Mode (Matches User Story 2 example)
            return "CPU\(Int(metrics.cpuUsage)} GPU\(Int(metrics.gpuUsage)} MEM\(Int(metrics.memoryUsage)} MP:\(metrics.memoryPressure.prefix(1)) SW\(Int(metrics.swapUsage)} TH:\(metrics.thermalPressure.prefix(1)) F\(metrics.fanRpm)"
        case .iconMode:
            // FR-015: Icon Mode
            return "📊"
        }
    }
}
