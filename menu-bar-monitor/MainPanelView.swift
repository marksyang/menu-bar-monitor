import SwiftUI

struct MainPanelView: View {
    @State private var metrics = SystemMetrics()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Overview")
                .font(.headline)
            
            MetricRow(name: "CPU Usage", value: String(format: "%.1f%%", metrics.cpuUsage))
            MetricRow(name: "GPU Usage", value: String(format: "%.1f%%", metrics.gpuUsage))
            MetricRow(name: "Unified Memory", value: String(format: "%.1f%%", metrics.memoryUsage))
            MetricRow(name: "Temperature", value: String(format: "%.1f°C", metrics.temperature))
            MetricRow(name: "Fan RPM", value: metrics.fanRpm == -1 ? "N/A" : "\(metrics.fanRpm) RPM")
            MetricRow(name: "Memory Pressure", value: metrics.memoryPressure)
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}

struct MetricRow: View {
    var name: String
    var value: String
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
