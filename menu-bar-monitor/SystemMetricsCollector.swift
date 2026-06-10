import Foundation
import Darwin
import IOKit

/// A pure Swift wrapper around Darwin C functions for system telemetry.
/// This avoids the need for a separate Objective-C bridging header.
struct SystemMetricsCollector {
    
    // MARK: - CPU Usage
    static func fetchCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let status = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }
//        guard let smc = SMCReader() else {
//            print("SMCReader init failed — open() returned false")
//            print("IOServiceGetMatchingServices result needs checking")
//            return 0.0
//        }
//        // 在 debugRead 確認後，批次掃描常見溫度 key
//        let tempKeys = [
//            "TB0T", "TB1T", "TB2T", "TB3T",  // Battery
//            "TW0P",                            // WiFi
//            "Tm0P", "Tm1P",                    // Memory
//            "THSP",                            // Thunderbolt
//            "TN0D", "TN0P",                    // Northbridge
//            "Te0T",                            // eGPU
//            "Tp01", "Tp05", "Tp0D", "Tp0b",   // Apple Silicon CPU
//            "Tp0j", "Tp0r", "Tp0X", "Tp0Z",
//            "Tg0f", "Tg0j",                    // Apple Silicon GPU
//            "FNum", "F0Ac", "F0Mn", "F0Mx", "F0Tg", "F0Md",  //Fan
//            "PFDC", "PC3S", "PC4S", "CGPA", "PCPC", "PG0R", "PSTR", // CPU Power
//            "PG0R", "PG0W", "PGTR", "PGPC", "PFDG", "PFGC", "PFCC", // GPU Power
//        ]
//
//        for k in tempKeys {
//            let result = smc.debugRead(keyStr: k)
//            if !result.contains("0B]") && !result.contains("read failed") {
//                print(result)  // 只印出存在的
//            }
//        }
        
        guard status == KERN_SUCCESS else { return 0.0 }
        let user = cpuInfo.cpu_ticks.0
        let system = cpuInfo.cpu_ticks.1
        let idle = cpuInfo.cpu_ticks.2
        let nice = cpuInfo.cpu_ticks.3
        
        let total = user + system + idle + nice
        guard total > 0 else { return 0.0 }
        
        return (1.0 - (Double(idle) / Double(total))) * 100.0
    }
    
    // MARK: - Memory Usage
    static func fetchMemoryStats() -> (usedPercent: Double, swapUsed: Double, pressure: String) {
        var totalMem: size_t = 0
        var totalMemLen: size_t = MemoryLayout<size_t>.stride
        sysctlbyname("hw.memsize", &totalMem, &totalMemLen, nil, 0)
        guard totalMem > 0 else { return (0.0, 0.0, "Unknown") }
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0.0, 0.0, "Unknown") }
        
        let pageSize = vm_page_size
        let totalPages = Double(totalMem) / Double(pageSize)
        
        // macOS: 已使用記憶體包含 Active, Inactive, Wired 與 Compressor 頁框
        let usedPages = Double(vmStats.active_count) + 
                        Double(vmStats.inactive_count) + 
                        Double(vmStats.wire_count) + 
                        Double(vmStats.compressor_page_count)
        
        let usedPercent = (usedPages / totalPages) * 100.0
        
        var swapUsage = VM_Swap_Usage()
        var swapUsageSize: size_t = MemoryLayout<VM_Swap_Usage>.stride
        sysctlbyname("vm.swapusage", &swapUsage, &swapUsageSize, nil, 0)
        let swapUsed = Double(swapUsage.used) / (1024.0 * 1024.0)
        
        let freePages = Double(vmStats.free_count)
        let pressure: String
        if freePages < totalPages * 0.02 {
            pressure = "Critical"
        } else if freePages < totalPages * 0.05 {
            pressure = "Warning"
        } else {
            pressure = "Normal"
        }
        
        return (usedPercent.rounded(), swapUsed.rounded(), pressure)
    }
    
    // MARK: - Fan RPM
    /// Reads fan RPM via IOKit. Works reliably on Intel Macs.
    /// On Apple Silicon, public APIs do not expose fan RPM directly without private frameworks.
    /// Returns -1 if fans are unavailable (e.g., MacBook Air) or unreadable.
    static func fetchFanRPM() -> Int {
        guard let smc = SMCReader() else { return -1 }
        let count = smc.fanCount()
        guard count > 0 else { return 0 }  // M 系列靜音模式下風扇不轉
        return smc.fanRPM(index: 0)
    }
    
    // MARK: - CPU Temperature
    /// Reads primary system/CPU temperature via SMC.
    static func fetchCPUTemperature() -> Double {
        guard let smc = SMCReader() else { return 0.0 }
        return smc.readCPUTemperature()
    }
    
    // MARK: - GPU Temperature
    /// Reads GPU temperature via SMC.
    static func fetchGPUTemperature() -> Double {
        guard let smc = SMCReader() else { return 0.0 }
        return smc.readGPUTemperature()
    }
    
    // MARK: - CPU Power
    /// Reads CPU power draw via SMC. Public API support varies by hardware.
    static func fetchCPUPower() -> Double {
        guard let smc = SMCReader() else { return 0.0 }
        return smc.readCPUPower()
    }
    
    // MARK: - GPU Power
    /// Reads GPU power draw via SMC. Public API support varies by hardware.
    static func fetchGPUPower() -> Double {
        guard let smc = SMCReader() else { return 0.0 }
        return smc.readGPUPower()
    }
    
    // MARK: - CPU Power
    /// Reads CPU power draw via SMC. Public API support varies by hardware.
    static func fetchSystemPower() -> Double {
        guard let smc = SMCReader() else { return 0.0 }
        return smc.readSystemPower()
    }
    
    // MARK: - Disk Usage
    static func fetchDiskUsage() -> Double {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            
            let total = Double(values.volumeTotalCapacity ?? 1)
            let available = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let used = total - available
            
            return (used / total) * 100.0
        } catch {
            return 0.0
        }
    }
    
    private struct VM_Swap_Usage {
        var total: vm_size_t = 0
        var used: vm_size_t = 0
        var free: vm_size_t = 0
        var inactive: vm_size_t = 0
        var active: vm_size_t = 0
    }
}
