import Foundation
import SwiftUI

@Observable
class SystemMonitorService {
    var metrics = SystemMetrics()
    var isRunning = false
    
    private var fastPollTask: Task<Void, Never>?
    private var slowPollTask: Task<Void, Never>?
    private var diskPollTask: Task<Void, Never>?
    private var powerHistory: [Double] = []
    private let powerHistorySize = 5  // 取最近 5 次平均

    private func smoothedPower(_ newValue: Double) -> Double {
        powerHistory.append(newValue)
        if powerHistory.count > powerHistorySize {
            powerHistory.removeFirst()
        }
        return powerHistory.reduce(0, +) / Double(powerHistory.count)
    }
    
    // MARK: - 熱壓力計算
    private func calculateThermalPressure(cpuTemp: Double, gpuTemp: Double) -> String {
        let maxTemp = max(cpuTemp, gpuTemp)
        switch maxTemp {
        case ..<60:
            return "Nominal"
        case ..<75:
            return "Fair"
        case ..<90:
            return "Elevated"
        case ..<100:
            return "Warning"
        default:
            return "Critical"

        }
    }

    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        // FR-003, FR-005, FR-007, FR-012: 1-second update loop
        fastPollTask = Task { [weak self] in
            while true {
                guard let self else { return }
                
                // 背景計算，不卡 UI
                let cpuUsage = SystemMetricsCollector.fetchCPUUsage()
                let gpuUsage = SystemMetricsCollector.fetchGPUUsage()
                let memStats = SystemMetricsCollector.fetchMemoryStats()  // 只呼叫一次
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.metrics.cpuUsage       = cpuUsage
                    self.metrics.gpuUsage       = gpuUsage
                    self.metrics.memoryUsage    = memStats.usedPercent
                    self.metrics.memoryPressure = memStats.pressure
                    self.metrics.swapUsage      = memStats.swapUsed
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        
        // FR-004, FR-006, FR-010, FR-011: 3-second update loop
        slowPollTask = Task { [weak self] in
            while true {
                guard let self else { return }
                
                // SMC 讀取在背景做，不卡 UI
                let cpuTemp    = SystemMetricsCollector.fetchCPUTemperature()
                let gpuTemp    = SystemMetricsCollector.fetchGPUTemperature()
                let cpuPower   = SystemMetricsCollector.fetchCPUPower()
                let gpuPower   = SystemMetricsCollector.fetchGPUPower()
                let sysPower   = SystemMetricsCollector.fetchSystemPower()
                let fan0Rpm    = SystemMetricsCollector.fetchFanRPM()[0]
                let fan1Rpm    = SystemMetricsCollector.fetchFanRPM()[1]
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.metrics.cpuTemperature  = cpuTemp
                    self.metrics.gpuTemperature  = gpuTemp
                    // ← 替換為動態計算的熱壓力狀態
                    self.metrics.thermalPressure = self.calculateThermalPressure(cpuTemp: cpuTemp, gpuTemp: gpuTemp)
                    self.metrics.cpuPower        = cpuPower
                    self.metrics.gpuPower        = gpuPower
                    self.metrics.systemPower     = self.smoothedPower(sysPower)
                    self.metrics.fan0Rpm         = fan0Rpm
                    self.metrics.fan1Rpm         = fan1Rpm
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
        
        // FR-013: 30-second update loop for Disk
        diskPollTask = Task { [weak self] in
            while true {
                await MainActor.run {
                    self?.metrics.diskUsage = SystemMetricsCollector.fetchDiskUsage()
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
    
    func stopMonitoring() {
        isRunning = false
        fastPollTask?.cancel()
        slowPollTask?.cancel()
        diskPollTask?.cancel()
    }
}
