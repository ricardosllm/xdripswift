//
//  Libre2Decryption.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import CryptoKit

/// Handles Libre 2 BLE data decryption on Apple Watch
enum Libre2Decryption {
    
    // MARK: - Constants
    
    private static let key: [UInt16] = [0xA0C5, 0x6860, 0x0000, 0x14C6]
    private static let secret: UInt16 = 0x1b6a
    
    // MARK: - Public Methods
    
    /// Decrypts Libre 2 BLE payload
    /// - Parameters:
    ///   - uid: Sensor UID (8 bytes)
    ///   - data: Encrypted BLE data (46 bytes)
    /// - Returns: Decrypted data
    /// - Throws: DecryptionError if decryption or validation fails
    static func decryptBLE(uid: Data, data: Data) throws -> Data {
        guard uid.count == 8 else {
            throw DecryptionError.invalidUID
        }
        
        guard data.count == 46 else {
            throw DecryptionError.invalidDataLength
        }
        
        let d = usefulFunction(id: uid, x: UInt16(0x1A), y: secret)
        let x = UInt16(d[1]) << 8 | UInt16(d[0]) ^ UInt16(d[3]) << 8 | UInt16(d[2]) | 0x63
        let y = UInt16(data[1]) << 8 | UInt16(data[0]) ^ 0x63
        
        var key = [UInt8]()
        var initialKey = processCrypto(input: prepareVariables(id: uid, x: x, y: y))
        
        for _ in 0..<8 {
            key.append(UInt8(truncatingIfNeeded: initialKey[0]))
            key.append(UInt8(truncatingIfNeeded: initialKey[0] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[1]))
            key.append(UInt8(truncatingIfNeeded: initialKey[1] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[2]))
            key.append(UInt8(truncatingIfNeeded: initialKey[2] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[3]))
            key.append(UInt8(truncatingIfNeeded: initialKey[3] >> 8))
            initialKey = processCrypto(input: initialKey)
        }
        
        var result = Data()
        let dataToDecrypt = data.subdata(in: 2..<data.count)
        
        for (index, byte) in dataToDecrypt.enumerated() {
            result.append(byte ^ key[index])
        }
        
        // Verify CRC
        let payloadCRC = UInt16(result[42]) | (UInt16(result[43]) << 8)
        let calculatedCRC = crc16(Data(result.prefix(42)))
        
        guard payloadCRC == calculatedCRC else {
            throw DecryptionError.crcMismatch
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    private static func prepareVariables(id: Data, x: UInt16, y: UInt16) -> [UInt16] {
        let s1 = UInt16(truncatingIfNeeded: UInt(UInt16(id[5]) << 8 | UInt16(id[4])) + UInt(x) + UInt(y))
        let s2 = UInt16(truncatingIfNeeded: UInt(UInt16(id[3]) << 8 | UInt16(id[2])) + UInt(key[2]))
        let s3 = UInt16(truncatingIfNeeded: UInt(UInt16(id[1]) << 8 | UInt16(id[0])) + UInt(x) * 2)
        let s4 = 0x241a ^ key[3]
        
        return [s1, s2, s3, s4]
    }
    
    private static func processCrypto(input: [UInt16]) -> [UInt16] {
        func op(_ value: UInt16) -> UInt16 {
            var res = value >> 2
            
            if value & 1 != 0 {
                res = res ^ key[1]
            }
            
            if value & 2 != 0 {
                res = res ^ key[0]
            }
            
            return res
        }
        
        let r0 = op(input[0]) ^ input[3]
        let r1 = op(r0) ^ input[2]
        let r2 = op(r1) ^ input[1]
        let r3 = op(r2) ^ input[0]
        let r4 = op(r3)
        let r5 = op(r4 ^ r0)
        let r6 = op(r5 ^ r1)
        let r7 = op(r6 ^ r2)
        
        let f1 = r0 ^ r4
        let f2 = r1 ^ r5
        let f3 = r2 ^ r6
        let f4 = r3 ^ r7
        
        return [f4, f3, f2, f1]
    }
    
    private static func usefulFunction(id: Data, x: UInt16, y: UInt16) -> Data {
        let blockKey = processCrypto(input: prepareVariables(id: id, x: x, y: y))
        let low = blockKey[0]
        let high = blockKey[1]
        
        let r1 = low ^ 0x4163
        let r2 = high ^ 0x4344
        
        return Data([
            UInt8(truncatingIfNeeded: r1),
            UInt8(truncatingIfNeeded: r1 >> 8),
            UInt8(truncatingIfNeeded: r2),
            UInt8(truncatingIfNeeded: r2 >> 8)
        ])
    }
    
    private static func crc16(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        
        return crc
    }
}

// MARK: - Error Types

enum DecryptionError: LocalizedError {
    case invalidUID
    case invalidDataLength
    case crcMismatch
    
    var errorDescription: String? {
        switch self {
        case .invalidUID:
            return "Invalid sensor UID"
        case .invalidDataLength:
            return "Invalid data length"
        case .crcMismatch:
            return "CRC validation failed"
        }
    }
}