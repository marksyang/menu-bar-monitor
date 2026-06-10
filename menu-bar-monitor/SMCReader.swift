//
//  SMCKey.swift
//  menu-bar-monitor
//
//  Created by Mark S.Yang on 2026/6/10.
//


import IOKit

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
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC"),
            &iterator
        ) == kIOReturnSuccess else { return false }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        isOpen = result == kIOReturnSuccess
        return isOpen
    }

    private func close() {
        guard isOpen else { return }
        IOServiceClose(connection)
        isOpen = false
    }

    // MARK: - 核心讀取
    private func call(
        _ selector: SMCSelector,
        input: SMCParamStruct
    ) throws -> SMCParamStruct {
        var inputCopy = input
        var output = SMCParamStruct()
        var inputSize  = MemoryLayout<SMCParamStruct>.size
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = IOConnectCallStructMethod(
            connection,
            selector.rawValue,
            &inputCopy, inputSize,
            &output,   &outputSize
        )
        guard result == kIOReturnSuccess else {
            throw SMCError.ioReturnError(result)
        }
        return output
    }

    private func keyInfo(for key: UInt32) throws -> SMCKeyInfoData {
        var input = SMCParamStruct()
        input.key = key
        input.data8 = UInt8(SMCSelector.getKeyInfo.rawValue)
        let output = try call(.getKeyInfo, input: input)
        return output.keyInfo
    }

    func readKey(_ key: UInt32) throws -> SMCParamStruct {
        let info = try keyInfo(for: key)
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = info.dataSize
        input.data8 = UInt8(SMCSelector.readKey.rawValue)
        return try call(.readKey, input: input)
    }

    // MARK: - Fan RPM（fp2e 格式解碼）
    func fanRPM(index: Int = 0) -> Int {
        // key 格式：F0Ac、F1Ac … 依 index
        let keyStr = "F\(index)Ac"
        let key = keyStr.utf8.prefix(4).reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
        guard let output = try? readKey(key) else { return -1 }

        // fp2e（fpe2）= Fixed Point, 2 integer bits + 14 fractional bits
        let msb = UInt16(output.bytes.0)
        let lsb = UInt16(output.bytes.1)
        let raw = (msb << 8) | lsb
        return Int(raw >> 2)   // 右移 2 bit 取整數部分
    }

    func fanCount() -> Int {
        guard let output = try? readKey(SMCKey.fanCount) else { return 0 }
        return Int(output.bytes.0)
    }
}

// MARK: - Error
enum SMCError: Error {
    case ioReturnError(IOReturn)
}
