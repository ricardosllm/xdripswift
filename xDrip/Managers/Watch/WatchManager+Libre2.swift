//
//  WatchManager+Libre2.swift
//  xdrip
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import WatchConnectivity
import OSLog
import UIKit

extension WatchManager {
    
    // MARK: - Libre 2 Connection Arbitration
    
    /// Handle arbitration messages from Watch
    func handleLibre2ArbitrationMessage(_ message: String) {
        let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
        trace("Received Libre 2 arbitration message: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, message)
        
        switch message {
        case "watchRequestingConnection":
            handleWatchConnectionRequest()
            
        case "watchConnected":
            let log2 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Watch connected to Libre 2 sensor", log: log2, category: ConstantsLog.categoryWatchManager, type: .info)
            UserDefaults.standard.watchIsConnectedToLibre2 = true
            // Post notification for UI feedback
            NotificationCenter.default.post(
                name: .libre2WatchConnectionUpdate,
                object: nil,
                userInfo: ["state": "connected"]
            )
            
        case "watchDisconnected":
            let log3 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Watch disconnected from Libre 2 sensor", log: log3, category: ConstantsLog.categoryWatchManager, type: .info)
            UserDefaults.standard.watchIsConnectedToLibre2 = false
            // Post notification for UI feedback
            NotificationCenter.default.post(
                name: .libre2WatchConnectionUpdate,
                object: nil,
                userInfo: ["state": "disconnected"]
            )
            
        case "watchAcknowledgeDisconnect":
            let log4 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Watch acknowledged disconnect request", log: log4, category: ConstantsLog.categoryWatchManager, type: .info)
            // Watch has disconnected, we can proceed with iPhone connection
            
        case "watchConnecting":
            let log5 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Watch is connecting to Libre 2 sensor", log: log5, category: ConstantsLog.categoryWatchManager, type: .info)
            // Post notification for UI feedback
            NotificationCenter.default.post(
                name: .libre2WatchConnectionUpdate,
                object: nil,
                userInfo: ["state": "connecting"]
            )
            
        case "watchConnectionFailed":
            let log6 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Watch failed to connect to Libre 2 sensor", log: log6, category: ConstantsLog.categoryWatchManager, type: .error)
            UserDefaults.standard.watchIsConnectedToLibre2 = false
            // Post notification for UI feedback
            NotificationCenter.default.post(
                name: .libre2WatchConnectionUpdate,
                object: nil,
                userInfo: ["state": "failed", "error": "Watch failed to connect to sensor"]
            )
            
        default:
            let log7 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
            trace("Unknown arbitration message: %{public}@", log: log7, category: ConstantsLog.categoryWatchManager, type: .error, message)
        }
    }
    
    /// Handle Watch requesting to connect
    private func handleWatchConnectionRequest() {
        let priority = UserDefaults.standard.libre2DirectPriority
        
        switch priority {
        case .iPhone:
            // iPhone always has priority
            if let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
               bluetoothPeripheralManager.isConnectedToLibre2() {
                // iPhone is connected, deny Watch request
                sendArbitrationMessage("iPhoneWantsToConnect")
            } else {
                // iPhone is not connected, but still has priority
                // Let Watch know iPhone might want to connect
                sendArbitrationMessage("iPhonePriority")
            }
            
        case .watch:
            // Watch always has priority
            // Check if iPhone needs to disconnect
            if let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
               bluetoothPeripheralManager.isConnectedToLibre2() {
                // iPhone is connected but Watch has priority
                // Initiate iPhone disconnection
                bluetoothPeripheralManager.requestLibre2DisconnectForWatch()
                sendArbitrationMessage("iPhoneDisconnecting")
            } else {
                // iPhone is not connected, allow Watch
                sendArbitrationMessage("iPhoneDisconnected")
            }
            
        case .auto:
            // Auto mode: iPhone when app is active, Watch otherwise
            let appIsActive = UIApplication.shared.applicationState == .active
            
            if appIsActive {
                // App is active, iPhone has priority
                if let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
                   bluetoothPeripheralManager.isConnectedToLibre2() {
                    // iPhone is connected, deny Watch request
                    sendArbitrationMessage("iPhoneWantsToConnect")
                } else {
                    // iPhone is not connected but app is active
                    sendArbitrationMessage("iPhonePriority")
                }
            } else {
                // App is not active, Watch has priority
                if let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
                   bluetoothPeripheralManager.isConnectedToLibre2() {
                    // iPhone is connected but Watch has priority
                    bluetoothPeripheralManager.requestLibre2DisconnectForWatch()
                    sendArbitrationMessage("iPhoneDisconnecting")
                } else {
                    // iPhone is not connected, allow Watch
                    sendArbitrationMessage("iPhoneDisconnected")
                }
            }
        }
    }
    
    /// Send arbitration message to Watch
    func sendArbitrationMessage(_ message: String) {
        guard WCSession.default.isPaired && WCSession.default.isWatchAppInstalled else { return }
        
        let messageDict = ["arbitration": message]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
                trace("Error sending arbitration message: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
            }
        }
    }
    
    /// Notify Watch when iPhone wants to connect to Libre 2
    func notifyWatchOfiPhoneConnectionIntent() {
        sendArbitrationMessage("iPhoneWantsToConnect")
    }
    
    /// Notify Watch when iPhone has disconnected from Libre 2
    func notifyWatchOfiPhoneDisconnection() {
        sendArbitrationMessage("iPhoneDisconnected")
    }
    
    // MARK: - Libre 2 Sensor Data Sharing
    
    /// Share Libre 2 sensor activation data with Watch
    func shareLibre2SensorData(uid: Data, patchInfo: Data, serialNumber: String, activationDate: Date, unlockCode: UInt32) {
        let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
        
        trace("shareLibre2SensorData called - checking Watch connection", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
        trace("WCSession isPaired: %{public}@, isWatchAppInstalled: %{public}@, isReachable: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, String(WCSession.default.isPaired), String(WCSession.default.isWatchAppInstalled), String(WCSession.default.isReachable))
        
        guard WCSession.default.isPaired && WCSession.default.isWatchAppInstalled else {
            trace("Watch not paired or app not installed", log: log, category: ConstantsLog.categoryWatchManager, type: .error)
            return
        }
        
        let sensorData: [String: Any] = [
            "uid": uid.hexEncodedString(),
            "patchInfo": patchInfo.hexEncodedString(),
            "serialNumber": serialNumber,
            "activationDate": activationDate.timeIntervalSince1970,
            "unlockCode": unlockCode,
            "unlockCount": UserDefaults.standard.libreActiveSensorUnlockCount
        ]
        
        trace("Preparing to send sensor data: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, sensorData.description)
        
        // Send via application context for persistence
        let applicationContext: [String: Any] = ["libre2SensorData": sensorData]
        
        do {
            try WCSession.default.updateApplicationContext(applicationContext)
            trace("Successfully updated application context with Libre 2 sensor data", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
        } catch {
            trace("Failed to update application context: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
        }
        
        // Also send immediately if Watch is reachable
        if WCSession.default.isReachable {
            trace("Watch is reachable, sending message directly", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            let message = ["libre2SensorData": sensorData]
            WCSession.default.sendMessage(message, replyHandler: { reply in
                trace("Received reply from Watch: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, reply.description)
            }) { error in
                trace("Error sending Libre 2 sensor data message: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .error, error.localizedDescription)
            }
        } else {
            trace("Watch is not reachable, relying on application context", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
        }
    }
    
    /// Share current Libre 2 sensor data if available
    func shareCurrentLibre2SensorData() {
        let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
        trace("shareCurrentLibre2SensorData called", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
        
        // Check if we have sensor data
        guard let sensorUID = UserDefaults.standard.libreSensorUID,
              let patchInfo = UserDefaults.standard.librePatchInfo else {
            trace("No Libre 2 sensor data available to share", log: log, category: ConstantsLog.categoryWatchManager, type: .info)
            return
        }
        
        trace("Found sensor data - UID: %{public}@, PatchInfo: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, sensorUID.hexEncodedString(), patchInfo.hexEncodedString())
        
        // Also sync the libre2DirectToWatchEnabled setting during handover
        let libre2Enabled = UserDefaults.standard.libre2DirectToWatchEnabled
        trace("Syncing libre2DirectToWatchEnabled setting: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, libre2Enabled.description)
        
        // Include the setting in state update
        sendStateToWatch(forceComplicationUpdate: false)
        
        // Get sensor serial number
        let sensorSerialNumber = LibreSensorSerialNumber(withUID: sensorUID, with: LibreSensorType.type(patchInfo: patchInfo.toHexString()))?.serialNumber ?? ""
        
        // Get unlock count (used as unlock code)
        let unlockCode = UInt32(UserDefaults.standard.libreActiveSensorUnlockCount)
        
        // Get sensor start date - for Libre 2, calculate from sensorTimeInMinutes
        var activationDate = Date()
        
        // Try to get the actual sensor start date from the connected Libre 2
        if let bluetoothPeripheralManager = self.bluetoothPeripheralManager,
           let libre2 = bluetoothPeripheralManager.getConnectedLibre2(),
           let sensorTimeInMinutes = libre2.sensorTimeInMinutes {
            // Calculate start date from sensor age
            activationDate = Date(timeIntervalSinceNow: -Double(sensorTimeInMinutes * 60))
            trace("Calculated sensor start date from sensorTimeInMinutes: %{public}@ (%{public}@ minutes ago)", log: log, category: ConstantsLog.categoryWatchManager, type: .info, activationDate.description, String(sensorTimeInMinutes))
        } else if let storedDate = UserDefaults.standard.activeSensorStartDate {
            // Fallback to stored date if available
            activationDate = storedDate
            trace("Using stored activeSensorStartDate: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, activationDate.description)
        } else {
            // Last resort - use current date (this is wrong but better than crashing)
            trace("WARNING: No sensor start date available, using current date as fallback", log: log, category: ConstantsLog.categoryWatchManager, type: .error)
        }
        
        // Add console logging for debugging
        print("=== SENSOR DATA DEBUG ===")
        print("Final activation date: \(activationDate)")
        print("activeSensorDescription: \(UserDefaults.standard.activeSensorDescription ?? "nil")")
        
        trace("Sharing sensor data - Serial: %{public}@, UnlockCode: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, sensorSerialNumber, String(unlockCode))
        
        // Log sensor data verification
        let sensorAge = Calendar.current.dateComponents([.minute], from: activationDate, to: Date()).minute ?? 0
        trace("Sensor verification - Age: %{public}@ minutes (%{public}@ days), Activation: %{public}@", log: log, category: ConstantsLog.categoryWatchManager, type: .info, String(sensorAge), String(format: "%.1f", Double(sensorAge) / 1440.0), activationDate.description)
        
        // Share the data
        shareLibre2SensorData(uid: sensorUID, patchInfo: patchInfo, serialNumber: sensorSerialNumber, activationDate: activationDate, unlockCode: unlockCode)
    }
    
    /// Process glucose data received from Watch
    func processWatchGlucoseData(_ data: [String: Any]) {
        guard let glucose = data["watchGlucose"] as? Int,
              let dateInterval = data["date"] as? TimeInterval else {
            return
        }
        
        let date = Date(timeIntervalSince1970: dateInterval)
        
        let log8 = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
        trace("Received glucose from Watch: %{public}@ mg/dL at %{public}@", log: log8, category: ConstantsLog.categoryWatchManager, type: .info, glucose.description, date.description)
        
        // Create a notification for the app to handle
        NotificationCenter.default.post(
            name: .watchDidSendGlucoseData,
            object: nil,
            userInfo: [
                "glucose": glucose,
                "date": date,
                "source": "Watch"
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchDidSendGlucoseData = Notification.Name("watchDidSendGlucoseData")
    static let libre2WatchConnectionUpdate = Notification.Name("libre2WatchConnectionUpdate")
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    
    @objc dynamic var watchIsConnectedToLibre2: Bool {
        get {
            return bool(forKey: "watchIsConnectedToLibre2")
        }
        set {
            set(newValue, forKey: "watchIsConnectedToLibre2")
        }
    }
}