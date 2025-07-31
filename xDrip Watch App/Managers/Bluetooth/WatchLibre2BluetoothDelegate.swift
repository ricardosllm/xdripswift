//
//  WatchLibre2BluetoothDelegate.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreBluetooth
import os.log

/// Handles Libre 2 specific Bluetooth communication on Apple Watch
final class WatchLibre2BluetoothDelegate: NSObject {
    
    // MARK: - Properties
    
    /// Logger
    private let logger = Logger(subsystem: "com.xdrip.watchapp", category: "WatchLibre2BluetoothDelegate")
    
    /// Expected packet size for Libre 2
    private let expectedPacketSize = 46
    
    /// Buffer for assembling packets
    private var rxBuffer = Data()
    
    /// Timer for packet timeout
    private var packetTimer: Timer?
    
    /// Delegate for glucose data
    weak var glucoseDelegate: WatchLibre2GlucoseDelegate?
    
    /// Sensor UID for decryption
    private var sensorUID: Data?
    
    /// Patch info for decryption
    private var patchInfo: Data?
    
    /// Unlock code
    private var unlockCode: UInt32?
    
    /// Last packet timestamp
    private var lastPacketTime = Date()
    
    /// Packet counter for tracking
    private var packetCounter: UInt16 = 0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Configure with sensor activation data
    func configureSensor(uid: Data, patchInfo: Data, unlockCode: UInt32) {
        self.sensorUID = uid
        self.patchInfo = patchInfo
        self.unlockCode = unlockCode
        
        logger.info("Configured sensor - UID: \(uid.hexEncodedString()), Unlock: \(unlockCode)")
    }
    
    /// Reset state
    func reset() {
        rxBuffer.removeAll()
        packetTimer?.invalidate()
        packetCounter = 0
    }
    
    // MARK: - Private Methods
    
    private func processPacket(_ data: Data) {
        guard data.count == expectedPacketSize else {
            logger.error("Invalid packet size: \(data.count) bytes")
            return
        }
        
        logger.info("Processing Libre 2 packet #\(self.packetCounter)")
        
        // Increment packet counter
        packetCounter += 1
        
        // Decrypt the packet
        guard let sensorUID = sensorUID else {
            logger.error("Missing sensor UID for decryption")
            return
        }
        
        do {
            let decryptedData = try Libre2Decryption.decryptBLE(uid: sensorUID, data: data)
            logger.info("Successfully decrypted packet")
            
            // Parse glucose data
            if let glucoseData = parseGlucoseData(from: decryptedData) {
                glucoseDelegate?.watchLibre2Delegate(didReceiveGlucose: glucoseData)
            }
            
        } catch {
            logger.error("Decryption failed: \(error.localizedDescription)")
        }
    }
    
    private func parseGlucoseData(from data: Data) -> Libre2GlucoseData? {
        // Libre 2 BLE data format (after decryption):
        // 0-1: Current glucose (mg/dL)
        // 2-3: Historical glucose
        // 4-5: Trend data
        // 40-41: Sensor age in minutes
        // 42-43: CRC (already validated in decryption)
        
        guard data.count >= 44 else {
            logger.error("Decrypted data too short: \(data.count) bytes")
            return nil
        }
        
        let currentGlucose = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let sensorAge = UInt16(data[40]) | (UInt16(data[41]) << 8)
        
        // Parse trend values (sparse, at minutes: 0, 2, 4, 6, 7, 12, 15)
        var trendValues: [Libre2TrendValue] = []
        let trendOffsets = [0, 2, 4, 6, 7, 12, 15]
        
        for i in 0..<7 {
            let offset = i * 4
            let rawValue = readBits(data, offset, 0, 14)
            let rawTemperature = readBits(data, offset, 14, 12) << 2
            let temperatureAdjustment = readBits(data, offset, 26, 5) << 2
            let negativeAdjustment = readBits(data, offset, 31, 1) != 0
            
            let finalTemperatureAdjustment = negativeAdjustment ? -temperatureAdjustment : temperatureAdjustment
            
            let minutesAgo = trendOffsets[i]
            let timestamp = Date().addingTimeInterval(-Double(minutesAgo * 60))
            
            let trendValue = Libre2TrendValue(
                rawValue: rawValue,
                rawTemperature: rawTemperature,
                temperatureAdjustment: finalTemperatureAdjustment,
                timestamp: timestamp,
                minutesAgo: minutesAgo
            )
            
            trendValues.append(trendValue)
        }
        
        // Parse historical values (last 3 15-minute readings)
        var historicalValues: [Libre2HistoricalValue] = []
        for i in 0..<3 {
            let offset = 28 + (i * 4)
            let rawValue = readBits(data, offset, 0, 14)
            let rawTemperature = readBits(data, offset, 14, 12) << 2
            let temperatureAdjustment = readBits(data, offset, 26, 5) << 2
            let negativeAdjustment = readBits(data, offset, 31, 1) != 0
            
            let finalTemperatureAdjustment = negativeAdjustment ? -temperatureAdjustment : temperatureAdjustment
            
            let minutesAgo = 15 * (i + 1)
            let timestamp = Date().addingTimeInterval(-Double(minutesAgo * 60))
            
            let historicalValue = Libre2HistoricalValue(
                rawValue: rawValue,
                rawTemperature: rawTemperature,
                temperatureAdjustment: finalTemperatureAdjustment,
                timestamp: timestamp,
                index: i
            )
            
            historicalValues.append(historicalValue)
        }
        
        let glucoseData = Libre2GlucoseData(
            currentGlucose: currentGlucose,
            trendValues: trendValues,
            historicalValues: historicalValues,
            sensorAge: sensorAge,
            timestamp: Date()
        )
        
        logger.info("Parsed glucose: \(currentGlucose) mg/dL, sensor age: \(sensorAge) minutes")
        
        return glucoseData
    }
    
    private func readBits(_ data: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {
        guard byteOffset + 4 <= data.count else { return 0 }
        
        var value = 0
        for i in 0..<4 {
            value |= Int(data[byteOffset + i]) << (i * 8)
        }
        
        return (value >> bitOffset) & ((1 << bitCount) - 1)
    }
    
    private func startPacketTimer() {
        packetTimer?.invalidate()
        packetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.packetTimeout()
        }
    }
    
    private func packetTimeout() {
        logger.warning("Packet assembly timeout - resetting buffer")
        rxBuffer.removeAll()
    }
}

// MARK: - WatchBluetoothDelegate

extension WatchLibre2BluetoothDelegate: WatchBluetoothDelegate {
    
    func watchBluetoothManagerDidConnect(_ manager: WatchBluetoothManager, peripheral: CBPeripheral) {
        logger.info("Bluetooth connected - ready for Libre 2 data")
        reset()
        
        // Send unlock payload to start streaming
        sendUnlockPayload(to: manager)
        
        // Notify iPhone that Watch is now connected
        ConnectionArbitrationManager.shared.sendMessageToiPhone("watchConnected")
    }
    
    private func sendUnlockPayload(to manager: WatchBluetoothManager) {
        // Get sensor info from stored data
        guard let sensorUID = self.sensorUID,
              let patchInfo = self.patchInfo,
              let unlockCode = self.unlockCode else {
            logger.error("No sensor info available to send unlock payload")
            return
        }
        
        logger.info("Sending unlock payload - UID: \(sensorUID.hexEncodedString()), Unlock: \(unlockCode)")
        
        // Get unlock count from UserDefaults (should be synced from iPhone)
        let unlockCount = UserDefaults.standard.integer(forKey: "libre2UnlockCount")
        
        // Generate unlock payload using streamingUnlockPayload function
        let unlockPayload = streamingUnlockPayload(
            sensorUID: sensorUID,
            info: patchInfo,
            enableTime: unlockCode,
            unlockCount: UInt16(unlockCount)
        )
        
        logger.info("Unlock payload: \(Data(unlockPayload).hexEncodedString())")
        
        // Send the payload
        manager.sendData(Data(unlockPayload))
        
        // Increment unlock count for next time
        UserDefaults.standard.set(unlockCount + 1, forKey: "libre2UnlockCount")
    }
    
    // Libre 2 streaming unlock payload generation
    private func streamingUnlockPayload(sensorUID: Data, info: Data, enableTime: UInt32, unlockCount: UInt16) -> [UInt8] {
        // This is a simplified version - in production, use the full Libre2BLEUtilities
        var payload = [UInt8]()
        
        // Command byte
        payload.append(0x02)
        
        // Enable time (4 bytes)
        payload.append(UInt8(enableTime & 0xFF))
        payload.append(UInt8((enableTime >> 8) & 0xFF))
        payload.append(UInt8((enableTime >> 16) & 0xFF))
        payload.append(UInt8((enableTime >> 24) & 0xFF))
        
        // Unlock count (2 bytes)
        payload.append(UInt8(unlockCount & 0xFF))
        payload.append(UInt8((unlockCount >> 8) & 0xFF))
        
        // Calculate verifyCode based on sensor UID and patch info
        let verifyCode = calculateVerifyCode(sensorUID: sensorUID, patchInfo: info)
        payload.append(contentsOf: verifyCode)
        
        return payload
    }
    
    private func calculateVerifyCode(sensorUID: Data, patchInfo: Data) -> [UInt8] {
        // Simplified verify code calculation
        // In production, use the full PreLibre2.usefulFunction implementation
        var code = [UInt8](repeating: 0, count: 4)
        
        // Basic XOR of UID and patch info bytes
        for i in 0..<min(4, sensorUID.count) {
            code[i] = sensorUID[i] ^ (i < patchInfo.count ? patchInfo[i] : 0)
        }
        
        return code
    }
    
    func watchBluetoothManagerDidDisconnect(_ manager: WatchBluetoothManager) {
        logger.info("Bluetooth disconnected")
        reset()
        
        // Notify iPhone that Watch has disconnected
        ConnectionArbitrationManager.shared.sendMessageToiPhone("watchDisconnected")
    }
    
    func watchBluetoothManager(_ manager: WatchBluetoothManager, didReceiveData data: Data) {
        logger.info("Received BLE data: \(data.count) bytes")
        
        // Libre 2 sends data in 3 packets: 20 + 18 + 8 bytes
        rxBuffer.append(data)
        startPacketTimer()
        
        // Check if we have a complete packet
        if rxBuffer.count >= expectedPacketSize {
            let packet = rxBuffer.prefix(expectedPacketSize)
            rxBuffer.removeFirst(expectedPacketSize)
            packetTimer?.invalidate()
            
            processPacket(Data(packet))
        }
    }
}

// MARK: - Data Models

struct Libre2GlucoseData {
    let currentGlucose: UInt16
    let trendValues: [Libre2TrendValue]
    let historicalValues: [Libre2HistoricalValue]
    let sensorAge: UInt16
    let timestamp: Date
    
    var glucoseInMgDl: Int {
        // Check for error values
        if currentGlucose > 500 {
            return 0
        }
        return Int(currentGlucose)
    }
    
    var isValid: Bool {
        return currentGlucose > 0 && currentGlucose < 501
    }
}

struct Libre2TrendValue {
    let rawValue: Int
    let rawTemperature: Int
    let temperatureAdjustment: Int
    let timestamp: Date
    let minutesAgo: Int
    
    var glucoseValue: Int? {
        guard rawValue > 0 else { return nil }
        // Apply temperature compensation if needed
        return rawValue
    }
}

struct Libre2HistoricalValue {
    let rawValue: Int
    let rawTemperature: Int
    let temperatureAdjustment: Int
    let timestamp: Date
    let index: Int
    
    var glucoseValue: Int? {
        guard rawValue > 0 else { return nil }
        return rawValue
    }
}

// MARK: - Delegate Protocol

protocol WatchLibre2GlucoseDelegate: AnyObject {
    func watchLibre2Delegate(didReceiveGlucose data: Libre2GlucoseData)
}

