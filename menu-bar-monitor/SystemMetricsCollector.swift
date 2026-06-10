import Foundation
import Darwin

/// A pure Swift wrapper around Darwin C functions for system telemetry.
/// This avoids the need for a separate Objective-C bridging header.
struct SystemMetricsCollector {
    
    // MARK: - CPU Usage
    static func fetchCPUUsage() -> Double {
        var mib = [CTL_KERN, KERN_CP_TIME]
        var oldp = [Int64(0), Int64(0), Int64(0), Int64(0), Int64(0), Int64(0), Int64(0), Int64(0)]
        var oldlen = MemoryLayout.size(ofValue: oldp)
        
        // Read system CPU times (user, nice, system, idle, etc.)
        guard sysctl(&mib, UInt32(mib.count), &oldp, &oldlen, nil, 0) == 0 else {
            return 0.0
        }
        
        let total = oldp.reduce(0, +)
        guard total > 0 else { return 0.0 }
        
        // Calculate usage based on idle time (index 5)
        let idle = Double(oldp[5])
        return (1.0 - (idle / Double(total))) * 100.0
    }
    
    // MARK: - Memory Usage
    static func fetchMemoryStats() -> (usedPercent: Double, swapUsed: Double, pressure: String) {
        var pagesize: size_t = 0
        sysctlbyname("hw.memsize", nil, &pagesize, nil, 0)
        let totalMem = Double(pagesize)
        
        var vmStats = vm_statistics64()
        var count = vm_statistics64_count()
        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                sysctlbyname("hw.vmstats64", intPointer, &count, nil, 0)
            }
        }
        
        guard result == 0 else { return (0.0, 0.0, "Unknown") }
        
        let freePages = vmStats.free_count
        let activePages = vmStats.active_count
        let inactivePages = vmStats.inactive_count
        let speculativePages = vmStats.speculative_count
        let wiredPages = vmStats.wire_count
        
        let usedPages = totalMem / Double(pagesize) - Double(freePages) - Double(speculativePages)
        let usedPercent = (usedPages / (totalMem / Double(pagesize))) * 100.0
        
        // Memory Pressure (Simple heuristic based on pageouts vs pageins)
        let pageouts = vmStats.pageouts_64
        let pageins = vmStats.pageins_64
        let pressure: String
        if pageouts > pageins * 10 {
            pressure = "Critical"
        } else if pageouts > pageins {
            pressure = "Warning"
        } else {
            pressure = "Normal"
        }
        
        // Swap Usage
        var swapUsage: vm_swap_usage = vm_swap_usage()
        sysctlbyname("vm.swapusage", &swapUsage, &count, nil, 0)
        let swapUsed = Double(swapUsage.usage) / 1024.0 // Convert to KB to MB
        
        return (usedPercent.rounded(), swapUsed.rounded(), pressure)
    }
    
    // MARK: - Disk Usage
    static func fetchDiskUsage() -> Double {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            let total = values.volumeTotalCapacity ?? 1
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            let used = Double(total - available)
            return (used / Double(total)) * 100.0
        } catch {
            return 0.0
        }
    }
}
