//
//  Libre2GlucoseManager.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import WatchConnectivity
import os.log

/// Manages Libre 2 glucose data processing and storage on Apple Watch
final class Libre2GlucoseManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = Libre2GlucoseManager()
    
    /// Current glucose value
    @Published var currentGlucose: Int = 0
    
    /// Trend arrow
    @Published var trendArrow: TrendArrow = .flat
    
    /// Delta change
    @Published var deltaChange: Int = 0
    
    /// Last reading date
    @Published var lastReadingDate: Date?
    
    /// Connection source
    @Published var dataSource: DataSource = .none
    
    /// Historical glucose readings (last 24 hours)
    @Published var glucoseHistory: [GlucoseReading] = []
    
    /// Sensor info
    @Published var sensorInfo: SensorInfo?
    
    /// Logger
    private let logger = Logger(subsystem: "com.xdrip.watchapp", category: "Libre2GlucoseManager")
    
    /// Bluetooth components
    private let bluetoothManager = WatchBluetoothManager.shared
    private let libre2Delegate = WatchLibre2BluetoothDelegate()
    private let arbitrationManager = ConnectionArbitrationManager.shared
    
    /// Timer for reading intervals
    private var readingTimer: Timer?
    
    /// User settings
    private var readingInterval: Int = 5 // minutes
    private var directConnectionEnabled = false
    
    // MARK: - Types
    
    enum DataSource {
        case none
        case iPhone
        case watchDirect
        
        var description: String {
            switch self {
            case .none: return "No Data"
            case .iPhone: return "iPhone"
            case .watchDirect: return "Watch"
            }
        }
    }
    
    enum TrendArrow: String {
        case doubleUp = "↑↑"
        case singleUp = "↑"
        case fortyFiveUp = "↗"
        case flat = "→"
        case fortyFiveDown = "↘"
        case singleDown = "↓"
        case doubleDown = "↓↓"
        
        static func from(delta: Int, minutes: Int) -> TrendArrow {
            let rateOfChange = Double(delta) / Double(minutes)
            
            if rateOfChange >= 3.0 { return .doubleUp }
            else if rateOfChange >= 2.0 { return .singleUp }
            else if rateOfChange >= 1.0 { return .fortyFiveUp }
            else if rateOfChange <= -3.0 { return .doubleDown }
            else if rateOfChange <= -2.0 { return .singleDown }
            else if rateOfChange <= -1.0 { return .fortyFiveDown }
            else { return .flat }
        }
    }
    
    struct GlucoseReading: Codable {
        let value: Int
        let date: Date
        let source: String
        
        var ageInMinutes: Int {
            Int(Date().timeIntervalSince(date) / 60)
        }
    }
    
    struct SensorInfo: Codable {
        let uid: Data
        let patchInfo: Data
        let serialNumber: String
        let activationDate: Date
        let unlockCode: UInt32
        
        var ageInDays: Int {
            Calendar.current.dateComponents([.day], from: activationDate, to: Date()).day ?? 0
        }
        
        var remainingDays: Int {
            max(0, 14 - ageInDays)
        }
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupComponents()
        loadSettings()
        observeNotifications()
    }
    
    // MARK: - Setup
    
    private func setupComponents() {
        // Configure bluetooth delegate
        bluetoothManager.delegate = libre2Delegate
        libre2Delegate.glucoseDelegate = self
        
        // Configure arbitration
        arbitrationManager.configure(bluetoothManager: bluetoothManager)
    }
    
    private func loadSettings() {
        directConnectionEnabled = UserDefaults.standard.bool(forKey: "libre2DirectToWatchEnabled")
        readingInterval = UserDefaults.standard.integer(forKey: "watchReadingInterval")
        if readingInterval == 0 { readingInterval = 5 }
        
        // Load sensor info if exists
        if let sensorData = UserDefaults.standard.data(forKey: "libre2SensorInfo"),
           let info = try? JSONDecoder().decode(SensorInfo.self, from: sensorData) {
            sensorInfo = info
            configureSensor(info)
        }
        
        // Load glucose history
        if let historyData = UserDefaults.standard.data(forKey: "glucoseHistory"),
           let history = try? JSONDecoder().decode([GlucoseReading].self, from: historyData) {
            glucoseHistory = history.filter { $0.date > Date().addingTimeInterval(-24 * 60 * 60) }
        }
    }
    
    private func observeNotifications() {
        // Observe sensor data from iPhone
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSensorDataReceived(_:)),
            name: .libre2SensorDataReceived,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable direct Watch connection
    func setDirectConnectionEnabled(_ enabled: Bool) {
        directConnectionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "watchDirectConnectionEnabled")
        
        if enabled {
            startDirectConnection()
        } else {
            stopDirectConnection()
        }
    }
    
    /// Update reading interval
    func setReadingInterval(_ minutes: Int) {
        readingInterval = minutes
        UserDefaults.standard.set(minutes, forKey: "watchReadingInterval")
        
        if directConnectionEnabled {
            scheduleNextReading()
        }
    }
    
    /// Process glucose data from iPhone
    func processDataFromiPhone(_ data: [String: Any]) {
        guard let value = data["glucose"] as? Int,
              let dateInterval = data["date"] as? TimeInterval else {
            return
        }
        
        let date = Date(timeIntervalSince1970: dateInterval)
        
        // Update current values
        currentGlucose = value
        lastReadingDate = date
        dataSource = .iPhone
        
        // Calculate delta
        if let previousReading = glucoseHistory.first {
            let timeDiff = Int(date.timeIntervalSince(previousReading.date) / 60)
            deltaChange = value - previousReading.value
            trendArrow = TrendArrow.from(delta: deltaChange, minutes: timeDiff)
        }
        
        // Add to history
        addToHistory(value: value, date: date, source: "iPhone")
        
        logger.info("Processed iPhone glucose: \(value) mg/dL")
    }
    
    // MARK: - Private Methods
    
    private func startDirectConnection() {
        guard let sensorInfo = sensorInfo else {
            logger.error("No sensor info available for direct connection")
            return
        }
        
        // Request connection permission
        if arbitrationManager.requestConnection() {
            // Give iPhone time to disconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                // Start scanning with full serial number
                let fullSerial = sensorInfo.serialNumber
                self?.logger.info("Starting scan for sensor with full serial: \(fullSerial)")
                self?.bluetoothManager.startScanning(sensorSerialNumber: fullSerial)
                
                // Schedule next reading
                self?.scheduleNextReading()
            }
        }
    }
    
    private func stopDirectConnection() {
        readingTimer?.invalidate()
        bluetoothManager.disconnect()
        arbitrationManager.notifyDisconnected()
    }
    
    private func scheduleNextReading() {
        readingTimer?.invalidate()
        
        let interval = TimeInterval(readingInterval * 60)
        readingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performReading()
        }
    }
    
    private func performReading() {
        guard directConnectionEnabled else { return }
        
        // Check if we can connect
        if arbitrationManager.state == .iPhoneConnected {
            logger.info("iPhone is connected, skipping Watch reading")
            return
        }
        
        // Reconnect if needed
        if bluetoothManager.connectionState != .connected {
            startDirectConnection()
        }
    }
    
    private func configureSensor(_ info: SensorInfo) {
        libre2Delegate.configureSensor(
            uid: info.uid,
            patchInfo: info.patchInfo,
            unlockCode: info.unlockCode
        )
    }
    
    private func addToHistory(value: Int, date: Date, source: String) {
        let reading = GlucoseReading(value: value, date: date, source: source)
        
        // Insert at beginning (newest first)
        glucoseHistory.insert(reading, at: 0)
        
        // Keep only last 24 hours
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        glucoseHistory = glucoseHistory.filter { $0.date > cutoffDate }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(glucoseHistory) {
            UserDefaults.standard.set(encoded, forKey: "glucoseHistory")
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleSensorDataReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uidHex = userInfo["uid"] as? String,
              let patchInfoHex = userInfo["patchInfo"] as? String,
              let serialNumber = userInfo["serialNumber"] as? String,
              let activationInterval = userInfo["activationDate"] as? TimeInterval,
              let unlockCode = userInfo["unlockCode"] as? UInt32 else {
            logger.error("Invalid sensor data received")
            return
        }
        
        let uid = Data(hex: uidHex) ?? Data()
        let patchInfo = Data(hex: patchInfoHex) ?? Data()
        let activationDate = Date(timeIntervalSince1970: activationInterval)
        
        let info = SensorInfo(
            uid: uid,
            patchInfo: patchInfo,
            serialNumber: serialNumber,
            activationDate: activationDate,
            unlockCode: unlockCode
        )
        
        // Update on main thread to avoid SwiftUI publishing errors
        DispatchQueue.main.async { [weak self] in
            self?.sensorInfo = info
            self?.configureSensor(info)
            
            // Save sensor info
            if let encoded = try? JSONEncoder().encode(info) {
                UserDefaults.standard.set(encoded, forKey: "libre2SensorInfo")
            }
            
            self?.logger.info("Configured new sensor: \(serialNumber)")
            
            // Start connection if enabled
            if self?.directConnectionEnabled == true {
                self?.startDirectConnection()
            }
        }
    }
}

// MARK: - WatchLibre2GlucoseDelegate

extension Libre2GlucoseManager: WatchLibre2GlucoseDelegate {
    
    func watchLibre2Delegate(didReceiveGlucose data: Libre2GlucoseData) {
        guard data.isValid else {
            logger.warning("Received invalid glucose data")
            return
        }
        
        let value = data.glucoseInMgDl
        let date = data.timestamp
        
        // Update current values
        currentGlucose = value
        lastReadingDate = date
        dataSource = .watchDirect
        
        // Calculate delta from trend values
        if data.trendValues.count >= 2,
           let current = data.trendValues[0].glucoseValue,
           let previous = data.trendValues[1].glucoseValue {
            deltaChange = current - previous
            trendArrow = TrendArrow.from(delta: deltaChange, minutes: 2)
        }
        
        // Add to history
        addToHistory(value: value, date: date, source: "Watch")
        
        // Send to iPhone for sync
        sendGlucoseToiPhone(value: value, date: date)
        
        logger.info("Processed Watch glucose: \(value) mg/dL, sensor age: \(data.sensorAge) min")
    }
    
    private func sendGlucoseToiPhone(value: Int, date: Date) {
        guard WCSession.default.isReachable else { return }
        
        let message: [String: Any] = [
            "watchGlucose": value,
            "date": date.timeIntervalSince1970,
            "source": "Watch"
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
            self?.logger.error("Failed to send glucose to iPhone: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Extension

extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex
        for _ in 0..<len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}