import Foundation
import SwiftUI

/// The central observable service that drives the UI with live data.
@Observable
class SystemMonitorService {
    var metrics = SystemMetrics()
    var isRunning = false
    
    // Private task handles to allow cancellation
    private var fastPollTask: Task<Void, Never>?
    private var slowPollTask: Task<Void, Never>?
    private var diskPollTask: Task<Void, Never>?
    
    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        // FR-003, FR-005, FR-007, FR-012: 1-second update loop
        fastPollTask = Task { [weak self] in
            while true {
                await MainActor.run {
                    self?.metrics.cpuUsage = SystemMetricsCollector.fetchCPUUsage()
                    // Stub: GPU and Fan require IOKit entitlements in production
                    // For now, we simulate them or use sysctl if available
                    self?.metrics.memoryUsage = SystemMetricsCollector.fetchMemoryStats().usedPercent
                    self?.metrics.memoryPressure = SystemMetricsCollector.fetchMemoryStats().pressure
                    self?.metrics.swapUsage = SystemMetricsCollector.fetchMemoryStats().swapUsed
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        
        // FR-004, FR-006, FR-010, FR-011: 3-second update loop
        slowPollTask = Task { [weak self] in
            while true {
                await MainActor.run {
                    // These are typically slower to read (e.g., via IOPowerSource or sensors)
                    self?.metrics.temperature = 45.0 // Placeholder for SMC read
                    self?.metrics.thermalPressure = "Nominal"
                    self?.metrics.cpuPower = 12.5    // Placeholder for IOKit read
                    self?.metrics.gpuPower = 5.0     // Placeholder for IOKit read
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
