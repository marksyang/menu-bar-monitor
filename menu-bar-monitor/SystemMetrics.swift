import Foundation

/// The raw payload representing the current state of the hardware
struct SystemMetrics {
    var cpuUsage: Double = 0.0
    var gpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var memoryPressure: String = "Normal"
    var swapUsage: Double = 0.0
    var temperature: Double = 0.0
    var thermalPressure: String = "Nominal"
    var fanRpm: Int = -1 // -1 indicates N/A or error
    var diskUsage: Double = 0.0
    var cpuPower: Double = 0.0
    var gpuPower: Double = 0.0
}
