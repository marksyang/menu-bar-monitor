import Foundation

/// Identifies each trackable hardware metric
enum MonitorMetric: String, CaseIterable, Identifiable, Codable {
    case cpuUsage = "CPU"
    case gpuUsage = "GPU"
    case memoryUsage = "MEM"
    case memoryPressure = "MP"
    case swapUsage = "SW"
    case temperature = "TH"
    case thermalPressure = "TP"
    case fanRpm = "F"
    case diskUsage = "Disk"
    case cpuPower = "CPU_W"
    case gpuPower = "GPU_W"

    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cpuUsage: return "CPU Usage"
        case .gpuUsage: return "GPU Usage"
        case .memoryUsage: return "Unified Memory"
        case .memoryPressure: return "Memory Pressure"
        case .swapUsage: return "Swap Usage"
        case .temperature: return "Temperature"
        case .thermalPressure: return "Thermal Pressure"
        case .fanRpm: return "Fan RPM"
        case .diskUsage: return "Disk Usage"
        case .cpuPower: return "CPU Power"
        case .gpuPower: return "GPU Power"
        }
    }

    var unit: String {
        switch self {
        case .cpuUsage, .gpuUsage, .memoryUsage, .diskUsage: return "%"
        case .memoryPressure, .thermalPressure: return ""
        case .swapUsage: return "MB"
        case .cpuPower, .gpuPower: return "W"
        case .temperature: return "°C"
        case .fanRpm: return "RPM"
        }
    }
}
