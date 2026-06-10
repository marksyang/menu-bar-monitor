//
//  SMCKey.swift
//  menu-bar-monitor
//
//  Created by Mark S.Yang on 2026/6/10.
//


import IOKit
import Foundation

// MARK: - SMC Key 定義
private struct SMCKey {
    static let fan0Speed: UInt32 = fourCC("F0Ac")
    static let fanCount:  UInt32 = fourCC("FNum")
    
    static func fourCC(_ s: StaticString) -> UInt32 {
        let b = s.utf8Start
        return UInt32(b[0]) << 24
             | UInt32(b[1]) << 16
             | UInt32(b[2]) << 8
             | UInt32(b[3])
    }
}

// MARK: - SMC 結構體（reverse engineered，與 AppleSMC driver 對應）
private struct SMCVersion {
    var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0
    var reserved: UInt8 = 0, release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0, length: UInt16 = 0
    var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: IOByteCount32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    )
}

// MARK: - SMC Selector
private enum SMCSelector: UInt32 {
    case getKeyInfo  = 9
    case readKey     = 5
}

// MARK: - SMCReader
final class SMCReader {
    private var connection: io_connect_t = 0
    private(set) var isOpen = false

    init?() {
        guard open() else { return nil }
    }

    deinit { close() }

    private func open() -> Bool {
//        var iterator: io_iterator_t = 0
//        guard IOServiceGetMatchingServices(
//            kIOMainPortDefault,
//            IOServiceMatching("AppleSMC"),
//            &iterator
//        ) == kIOReturnSuccess else { return false }
//        defer { IOObjectRelease(iterator) }
//
//        let service = IOIteratorNext(iterator)
//        guard service != 0 else { return false }
//        defer { IOObjectRelease(service) }
//
//        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
//        isOpen = result == kIOReturnSuccess
//        return isOpen
        var iterator: io_iterator_t = 0
            let matchResult = IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching("AppleSMC"),
                &iterator
            )
            guard matchResult == kIOReturnSuccess else {
                print("IOServiceGetMatchingServices failed: \(matchResult)")
                return false
            }
            defer { IOObjectRelease(iterator) }

            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                print("No AppleSMC service found")  // ← 通常是這裡
                return false
            }
            defer { IOObjectRelease(service) }

            let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
            guard result == kIOReturnSuccess else {
                print("IOServiceOpen failed: \(result)")  // ← 或這裡（權限問題）
                return false
            }
            isOpen = true
            return true
    }

    private func close() {
        guard isOpen else { return }
        IOServiceClose(connection)
        isOpen = false
    }

    // MARK: - 核心讀取
//    private func call(
//        _ selector: SMCSelector,
//        input: SMCParamStruct
//    ) throws -> SMCParamStruct {
//        var inputCopy = input
//        var output = SMCParamStruct()
//        let inputSize  = MemoryLayout<SMCParamStruct>.size
//        var outputSize = MemoryLayout<SMCParamStruct>.size
//
//        let result = IOConnectCallStructMethod(
//            connection,
//            selector.rawValue,
//            &inputCopy, inputSize,
//            &output,   &outputSize
//        )
//        guard result == kIOReturnSuccess else {
//            throw SMCError.ioReturnError(result)
//        }
//        return output
//    }
    private func call(
        _ selector: SMCSelector,
        input: SMCParamStruct
    ) throws -> SMCParamStruct {
        var inputCopy = input
        inputCopy.data8 = UInt8(selector.rawValue)  // 這個保留
        var output = SMCParamStruct()
        let inputSize  = MemoryLayout<SMCParamStruct>.size
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            2,              // ← 這裡固定傳 2，不是 selector.rawValue
            &inputCopy, inputSize,
            &output,   &outputSize
        )
        guard result == kIOReturnSuccess else {
            throw SMCError.ioReturnError(result)
        }
        return output
    }

//    private func keyInfo(for key: UInt32) throws -> SMCKeyInfoData {
//        var input = SMCParamStruct()
//        input.key = key
//        input.data8 = UInt8(SMCSelector.getKeyInfo.rawValue)
//        let output = try call(.getKeyInfo, input: input)
//        return output.keyInfo
//    }
//
//    private func readKey(_ key: UInt32) throws -> SMCParamStruct {
//        let info = try keyInfo(for: key)
//        var input = SMCParamStruct()
//        input.key = key
//        input.keyInfo.dataSize = info.dataSize
//        input.data8 = UInt8(SMCSelector.readKey.rawValue)
//        return try call(.readKey, input: input)
//    }
    private func keyInfo(for key: UInt32) throws -> SMCKeyInfoData {
        var input = SMCParamStruct()
        input.key = key
        // data8 不用在這裡設，call() 裡會設
        let output = try call(.getKeyInfo, input: input)
        return output.keyInfo
    }

    private func readKey(_ key: UInt32) throws -> SMCParamStruct {
        let info = try keyInfo(for: key)
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = info.dataSize
        // data8 不用在這裡設，call() 裡會設
        return try call(.readKey, input: input)
    }
    
    private func decodeFlt(_ output: SMCParamStruct) -> Float {
        let b = output.bytes
//        let raw = UInt32(b.0) << 24 | UInt32(b.1) << 16 | UInt32(b.2) << 8 | UInt32(b.3)
        let raw = UInt32(b.3) << 24 | UInt32(b.2) << 16 | UInt32(b.1) << 8 | UInt32(b.0)
        return Float(bitPattern: raw)
    }

    // MARK: - Fan RPM（fp2e 格式解碼）
//    func fanRPM(index: Int = 0) -> Int {
//        // key 格式：F0Ac、F1Ac … 依 index
//        let keyStr = "F\(index)Ac"
//        let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) {
//            ($0 << 8) | UInt32($1)
//        }
//        guard let output = try? readKey(key) else { return -1 }
//
//        // fp2e（fpe2）= Fixed Point, 2 integer bits + 14 fractional bits
//        let msb = UInt16(output.bytes.0)
//        let lsb = UInt16(output.bytes.1)
//        let raw = (msb << 8) | lsb
//        return Int(raw >> 2)   // 右移 2 bit 取整數部分
//    }
    func fanRPM(index: Int = 0) -> Int {
        let keyStr = "F\(index)Ac"
        let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard let output = try? readKey(key) else { return -1 }
        return Int(decodeFlt(output))
    }

    func fanCount() -> Int {
        guard let output = try? readKey(SMCKey.fanCount) else { return 0 }
        return Int(output.bytes.0)
    }
    
    // MARK: - CPU Temperature
    func readCPUTemperature() -> Double {
        // Tp0j / Tp0X = CPU core，取平均
        let cpuKeys = ["Tp0j", "Tp0X"]
        var total: Float = 0
        var count = 0
        
        for keyStr in cpuKeys {
            let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard let output = try? readKey(key) else { continue }
            let temp = decodeFlt(output)
            if temp > 0 && temp < 120 {
                total += temp
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return Double(total / Float(count))
    }
    
    // MARK: - GPU Temperature
    func readGPUTemperature() -> Double {
        // Tp0j / Tp0X = CPU core，取平均
        let cpuKeys = ["Tg0j"]
        var total: Float = 0
        var count = 0
        
        for keyStr in cpuKeys {
            let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard let output = try? readKey(key) else { continue }
            let temp = decodeFlt(output)
            if temp > 0 && temp < 120 {
                total += temp
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return Double(total / Float(count))
    }
    
    // MARK: - Power (Watts)
    func readCPUPower() -> Double {
        // Common SMC keys for CPU power usage
        let keys = ["PFDC", "PC3S", "PC4S", "CGPA"]
        return readSMCPower(keys: keys)
    }
    
    func readGPUPower() -> Double {
        // Common SMC keys for GPU power usage
        let keys = ["PFDG", "PFGC", "PFCC"]
        return readSMCPower(keys: keys)
    }
    
    func readSystemPower() -> Double {
        // Common SMC keys for System power usage
        let keys = ["PSTR"]
        return readSMCPower(keys: keys)
    }
    
    private func readSMCPower(keys: [String]) -> Double {
        for keyStr in keys {
            let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard let output = try? readKey(key) else { continue }
            
            // SMC power values are typically sp78 (signed 7.8 fixed-point)
            let msb = UInt16(output.bytes.0)
            let lsb = UInt16(output.bytes.1)
            let raw = Int16(bitPattern: (msb << 8) | lsb)
            let power = Double(raw) / 256.0
            
            // Sanity check for realistic power draw (0.5W to 500W)
            if power > 0.5 && power < 500.0 {
                return power
            }
        }
        return 0.0
    }
    
//    func debugRead(keyStr: String) -> String {
//        let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
//        guard let output = try? readKey(key),
//              let info = try? keyInfo(for: key) else {
//            return "\(keyStr): read failed"
//        }
//        let typeStr = withUnsafeBytes(of: info.dataType.bigEndian) {
//            String(bytes: $0.filter { $0 != 0 }, encoding: .ascii) ?? "????"
//        }
//        let b = output.bytes
//        return "\(keyStr) [\(typeStr) \(info.dataSize)B]: \(b.0) \(b.1) \(b.2) \(b.3)"
//    }
    func debugRead(keyStr: String) -> String {
        let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard let output = try? readKey(key),
              let info = try? keyInfo(for: key) else {
            return "\(keyStr): read failed"
        }
        let typeStr = withUnsafeBytes(of: info.dataType.bigEndian) {
            String(bytes: $0.filter { $0 != 0 }, encoding: .ascii) ?? "????"
        }
        let b = output.bytes
        // 改成 hex
        return String(format: "\(keyStr) [\(typeStr) \(info.dataSize)B]: %02X %02X %02X %02X",
                      b.0, b.1, b.2, b.3)
    }
}

// MARK: - Error
enum SMCError: Error {
    case ioReturnError(IOReturn)
}
