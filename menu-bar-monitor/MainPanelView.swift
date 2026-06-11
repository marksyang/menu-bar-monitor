import SwiftUI
import AppKit

struct MainPanelView: View {
    @State private var monitorService = SystemMonitorService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Overview")
                    .font(.headline)
                Spacer()
                Image(systemName: "fan")
            }
            
            Divider()
            
            MetricRow(name: "CPU Usage", value: String(format: "%.1f%%", monitorService.metrics.cpuUsage))
            MetricRow(name: "GPU Usage", value: String(format: "%.1f%%", monitorService.metrics.gpuUsage))
            MetricRow(name: "Unified Memory", value: String(format: "%.1f%%", monitorService.metrics.memoryUsage))
            MetricRow(name: "Swap Usage", value: String(format: "%.1f MB", monitorService.metrics.swapUsage))
            MetricRow(name: "CPU Temperature", value: String(format: "%.1f°C", monitorService.metrics.cpuTemperature))
            MetricRow(name: "GPU Temperature", value: String(format: "%.1f°C", monitorService.metrics.gpuTemperature))
            MetricRow(name: "System Power", value: String(format: "%.1fW", monitorService.metrics.systemPower))
            MetricRow(name: "Fan 0 RPM", value: monitorService.metrics.fan0Rpm == -1 ? "N/A" : "\(monitorService.metrics.fan0Rpm) RPM")
            MetricRow(name: "Fan 1 RPM", value: monitorService.metrics.fan1Rpm == -1 ? "N/A" : "\(monitorService.metrics.fan0Rpm) RPM")
            
            Divider()
            
            HStack {
                StatusIndicator(title: "Memory Pressure", state: monitorService.metrics.memoryPressure)
                StatusIndicator(title: "Thermal Pressure", state: monitorService.metrics.thermalPressure)
            }
            
            Divider()
            
            // 關閉程式按鈕
            Button("關閉程式") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            .tint(.red)
            
            Spacer()
        }
        .padding()
        .frame(width: 320, height: 450)
        .task {
            monitorService.startMonitoring()
        }
        .onDisappear {
            monitorService.stopMonitoring()
        }
    }
}

struct MetricRow: View {
    var name: String
    var value: String
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.headline)
                .fontWeight(.medium)
        }
    }
}

struct StatusIndicator: View {
    var title: String
    var state: String
    
    private var color: Color {
        if state == "Critical" { return .red }
        if state == "Warning" || state == "Fair" { return .orange }
        return .green
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(state)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}
