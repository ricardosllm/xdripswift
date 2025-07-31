//
//  WatchBluetoothManager.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreBluetooth
import WatchKit
import os.log

/// Manages Bluetooth connections to Libre 2 sensors from Apple Watch
final class WatchBluetoothManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = WatchBluetoothManager()
    
    /// Central manager for BLE operations
    private var centralManager: CBCentralManager?
    
    /// Currently connected peripheral
    private var connectedPeripheral: CBPeripheral?
    
    /// Libre 2 service UUID
    private let libre2ServiceUUID = CBUUID(string: "FDE3")
    
    /// Libre 2 characteristics
    private let libre2WriteCharacteristicUUID = CBUUID(string: "F001")
    private let libre2NotifyCharacteristicUUID = CBUUID(string: "F002")
    
    /// Write characteristic
    private var writeCharacteristic: CBCharacteristic?
    
    /// Notify characteristic
    private var notifyCharacteristic: CBCharacteristic?
    
    /// Connection state
    @Published var connectionState: ConnectionState = .idle
    
    /// Last error
    @Published var lastError: Error?
    
    /// Extended runtime session for background operation
    private var extendedSession: WKExtendedRuntimeSession?
    
    /// Timer for connection timeout
    private var connectionTimer: Timer?
    
    /// Logger
    private let logger = Logger(subsystem: "com.xdrip.watchapp", category: "WatchBluetoothManager")
    
    /// Delegate for BLE operations
    weak var delegate: WatchBluetoothDelegate?
    
    /// Sensor serial number to connect to
    private var targetSensorSerialNumber: String?
    
    /// Known sensor address for faster reconnection
    private var knownSensorAddress: UUID?
    
    /// Potential sensors to check when name is unknown
    private var potentialSensors: [CBPeripheral] = []
    
    /// Number of scan attempts
    private var scanAttempts: Int = 0
    
    /// Connection arbitration state
    @Published var arbitrationState: ConnectionArbitrationState = .watchDisconnected
    
    // MARK: - Connection States
    
    enum ConnectionState: String {
        case idle = "Idle"
        case scanning = "Scanning"
        case connecting = "Connecting"
        case connected = "Connected"
        case disconnecting = "Disconnecting"
        case waitingForiPhone = "Waiting for iPhone"
        case error = "Error"
    }
    
    enum ConnectionArbitrationState {
        case iPhoneConnected
        case watchConnected
        case watchDisconnected
        case transitioning
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupExtendedSession()
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Libre 2 sensor
    func startScanning(sensorSerialNumber: String) {
        logger.info("Starting scan for sensor: \(sensorSerialNumber)")
        
        guard connectionState == .idle || connectionState == .error else {
            logger.warning("Cannot start scanning - current state: \(self.connectionState.rawValue)")
            return
        }
        
        targetSensorSerialNumber = sensorSerialNumber
        connectionState = .scanning
        scanAttempts = 0  // Reset scan attempts for new scan
        
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else if centralManager?.state == .poweredOn {
            performScan()
        }
    }
    
    /// Stop scanning
    func stopScanning() {
        logger.info("Stopping scan")
        centralManager?.stopScan()
        connectionTimer?.invalidate()
        connectionState = .idle
    }
    
    /// Disconnect from peripheral
    func disconnect() {
        logger.info("Disconnecting from peripheral")
        
        if let peripheral = connectedPeripheral {
            connectionState = .disconnecting
            centralManager?.cancelPeripheralConnection(peripheral)
        } else {
            connectionState = .idle
        }
    }
    
    /// Send data to the connected peripheral
    func sendData(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            logger.error("Cannot send data - not connected or missing write characteristic")
            return
        }
        
        logger.info("Sending data: \(data.count) bytes - hex: \(data.hexEncodedString())")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Handle iPhone connection state change
    func handleiPhoneConnectionStateChange(_ state: Bool) {
        logger.info("iPhone connection state changed: \(state)")
        
        if state {
            // iPhone wants to connect, we should disconnect
            arbitrationState = .transitioning
            disconnect()
            arbitrationState = .iPhoneConnected
        } else {
            // iPhone disconnected, we can connect
            arbitrationState = .watchDisconnected
            if let serial = targetSensorSerialNumber {
                startScanning(sensorSerialNumber: serial)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupExtendedSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
    }
    
    private func performScan() {
        logger.info("=== Starting BLE Scan ===")
        logger.info("Target sensor serial: \(self.targetSensorSerialNumber ?? "none")")
        logger.info("Expected device name: ABBOTT\(self.targetSensorSerialNumber ?? "")")
        
        // Clear any potential sensors from previous scan
        self.potentialSensors.removeAll()
        
        // Set up timeout - give more time within the 5-minute window
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.scanTimeout()
        }
        
        // Try to reconnect to known peripheral first
        if let knownAddress = knownSensorAddress {
            logger.info("Checking for known peripheral with ID: \(knownAddress)")
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [knownAddress])
            if let peripheral = peripherals?.first {
                logger.info("Found known peripheral, state: \(peripheral.state.rawValue)")
                if peripheral.state == .disconnected {
                    connectToPeripheral(peripheral)
                    return
                } else {
                    logger.warning("Known peripheral not disconnected, state: \(peripheral.state.rawValue)")
                }
            }
        }
        
        // Try different scan strategies
        logger.info("Starting scan with service UUID: FDE3")
        
        // First try scanning with service filter
        centralManager?.scanForPeripherals(withServices: [libre2ServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true  // Changed to true to see all advertisements
        ])
        
        // Immediately also scan without service filter
        // Most Libre 2 sensors don't advertise the service UUID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.connectionState == .scanning else { return }
            
            self.logger.info("Starting aggressive scan without service filter")
            self.logger.info("Will connect to: unnamed devices, devices with ABBOTT prefix, devices with manufacturer data")
            self.centralManager?.stopScan()
            self.centralManager?.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])
        }
    }
    
    private func scanTimeout() {
        logger.warning("Scan timeout reached, checking status...")
        
        // If we still have potential sensors to try, don't give up
        if !self.potentialSensors.isEmpty {
            logger.info("Still have \(self.potentialSensors.count) devices to check")
            return
        }
        
        // Stop current scan
        stopScanning()
        
        // Retry if we haven't exhausted attempts
        if self.scanAttempts < 3 {
            self.scanAttempts += 1
            logger.info("Retrying scan (attempt \(self.scanAttempts)/3)")
            
            // Clear potential sensors and try again with more aggressive strategy
            self.potentialSensors.removeAll()
            
            // Wait a moment then retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.performScan()
            }
        } else {
            // Final failure
            connectionState = .idle
            lastError = WatchBluetoothError.scanTimeout
            arbitrationState = .watchDisconnected
            
            // Notify iPhone of failure
            ConnectionArbitrationManager.shared.sendMessageToiPhone("watchConnectionFailed")
        }
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        logger.info("Connecting to peripheral: \(peripheral.identifier)")
        
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.connectionTimeout()
        }
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting
        centralManager?.connect(peripheral, options: nil)
        
        // Notify iPhone that Watch is trying to connect
        ConnectionArbitrationManager.shared.sendMessageToiPhone("watchConnecting")
    }
    
    private func connectionTimeout() {
        logger.warning("Connection timeout reached")
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectionState = .idle
        lastError = WatchBluetoothError.connectionTimeout
        arbitrationState = .watchDisconnected
    }
    
    // MARK: - Extended Session
    
    private func startExtendedSession() {
        guard extendedSession?.state != .running else { 
            logger.info("Extended session already running")
            return 
        }
        
        logger.info("Starting extended runtime session")
        extendedSession?.start()
    }
    
    private func stopExtendedSession() {
        extendedSession?.invalidate()
    }
}

// MARK: - CBCentralManagerDelegate

extension WatchBluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Central manager state updated: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            if connectionState == .scanning {
                performScan()
            }
        case .poweredOff:
            connectionState = .error
            lastError = WatchBluetoothError.bluetoothPoweredOff
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        logger.info("Discovered peripheral: \(peripheral.name ?? "Unknown") - RSSI: \(RSSI)")
        logger.info("Advertisement data: \(advertisementData)")
        
        // Log manufacturer data if present (Libre 2 often uses this)
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            logger.info("Manufacturer data: \(manufacturerData.hexEncodedString())")
        }
        
        // Check if this is our target sensor
        if let targetSerial = targetSensorSerialNumber {
            // Expected name format: "ABBOTT" + serial number
            let expectedName = "ABBOTT\(targetSerial)"
            
            // Check the peripheral name
            if let name = peripheral.name {
                logger.info("Checking if '\(name)' matches expected name '\(expectedName)'")
                
                // Check for exact match or if it contains ABBOTT with our serial
                if name == expectedName || 
                   (name.hasPrefix("ABBOTT") && name.contains(targetSerial)) ||
                   name.contains(targetSerial) {
                    
                    logger.info("Found matching Libre 2 sensor!")
                    knownSensorAddress = peripheral.identifier
                    
                    // Stop scan only for exact matches
                    central.stopScan()
                    connectToPeripheral(peripheral)
                    return
                }
                
                // Additional check for partial matches (in case serial format differs)
                if name.hasPrefix("ABBOTT") {
                    let serialPart = String(name.dropFirst(6)) // Remove "ABBOTT" prefix
                    logger.info("Found ABBOTT device with serial: '\(serialPart)'")
                    
                    // Check if this serial part matches any portion of our target
                    if targetSerial.contains(serialPart) || serialPart.contains(targetSerial) {
                        logger.info("Partial serial match found!")
                        central.stopScan()
                        knownSensorAddress = peripheral.identifier
                        connectToPeripheral(peripheral)
                        return
                    }
                }
            }
            
            // Also check if it's advertising the Libre 2 service
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
               serviceUUIDs.contains(libre2ServiceUUID) {
                logger.info("Found device advertising Libre 2 service (FDE3)")
                central.stopScan()
                knownSensorAddress = peripheral.identifier
                connectToPeripheral(peripheral)
                return
            }
            
            // Check manufacturer data for Abbott/Libre 2 signature
            // Abbott company ID is 0x1F (31 in decimal)
            if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
               manufacturerData.count >= 8 {
                // Check if it starts with Abbott company ID
                let companyID = manufacturerData[0..<2].withUnsafeBytes { $0.load(as: UInt16.self) }
                if companyID == 0x1F00 || companyID == 0x001F { // Check both endianness
                    logger.info("Found device with Abbott manufacturer data!")
                    central.stopScan()
                    knownSensorAddress = peripheral.identifier
                    connectToPeripheral(peripheral)
                    return
                }
            }
            
            // For Libre 2 sensors that don't advertise their name (show as "Unknown")
            // Connect to ALL unnamed devices - no RSSI filtering!
            if peripheral.name == nil || peripheral.name == "Unknown" || peripheral.name == "" {
                logger.info("Found unnamed device with RSSI \(RSSI), connecting to verify if Libre 2")
                
                // Avoid duplicates
                if !potentialSensors.contains(where: { $0.identifier == peripheral.identifier }) {
                    potentialSensors.append(peripheral)
                    
                    // Don't stop scan - keep looking while we connect
                    // This allows parallel discovery
                    connectToPeripheral(peripheral)
                    return
                }
            }
            
            // Also try any device with weak signal that we haven't tried yet
            // Libre 2 sensors can have very weak signals
            if RSSI.intValue > -95 && !potentialSensors.contains(where: { $0.identifier == peripheral.identifier }) {
                logger.info("Found device '\(peripheral.name ?? "Unknown")' with weak signal, worth trying")
                potentialSensors.append(peripheral)
                connectToPeripheral(peripheral)
                return
            }
            
            // Also check devices that advertise with just the serial number
            if let name = peripheral.name, name == targetSerial {
                logger.info("Found device with exact serial number as name!")
                central.stopScan()
                knownSensorAddress = peripheral.identifier
                connectToPeripheral(peripheral)
                return
            }
            
            // Log the name to help debug
            if let name = peripheral.name {
                logger.info("Device name: '\(name)' - Expected: 'ABBOTT\(targetSerial)'")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.identifier)")
        
        connectionTimer?.invalidate()
        connectionState = .connected
        arbitrationState = .watchConnected
        
        // Start extended session for background operation
        startExtendedSession()
        
        // Discover services
        peripheral.discoverServices([libre2ServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral. Error: \(error?.localizedDescription ?? "None")")
        
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        connectionState = .idle
        arbitrationState = .watchDisconnected
        
        stopExtendedSession()
        
        if let error = error {
            lastError = error
        }
        
        delegate?.watchBluetoothManagerDidDisconnect(self)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to peripheral. Error: \(error?.localizedDescription ?? "Unknown")")
        
        connectionTimer?.invalidate()
        connectionState = .error
        lastError = error ?? WatchBluetoothError.connectionFailed
        
        // Notify iPhone that Watch failed to connect
        ConnectionArbitrationManager.shared.sendMessageToiPhone("watchConnectionFailed")
    }
}

// MARK: - CBPeripheralDelegate

extension WatchBluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            logger.error("Error discovering services: \(error!.localizedDescription)")
            
            // If this was a potential sensor candidate that failed, disconnect and try next
            if potentialSensors.contains(where: { $0.identifier == peripheral.identifier }) {
                centralManager?.cancelPeripheralConnection(peripheral)
                potentialSensors.removeAll { $0.identifier == peripheral.identifier }
                
                // Resume scanning
                connectionState = .scanning
                centralManager?.scanForPeripherals(withServices: [libre2ServiceUUID], options: nil)
            }
            return
        }
        
        guard let services = peripheral.services else { return }
        
        var foundLibre2Service = false
        for service in services where service.uuid == libre2ServiceUUID {
            logger.info("Found Libre 2 service - this is our sensor!")
            foundLibre2Service = true
            
            // This is definitely a Libre 2 sensor
            knownSensorAddress = peripheral.identifier
            potentialSensors.removeAll()
            
            peripheral.discoverCharacteristics([libre2WriteCharacteristicUUID, libre2NotifyCharacteristicUUID], for: service)
        }
        
        // If we didn't find Libre 2 service and this was a potential candidate
        if !foundLibre2Service && potentialSensors.contains(where: { $0.identifier == peripheral.identifier }) {
            logger.info("Device is not a Libre 2 sensor, disconnecting")
            centralManager?.cancelPeripheralConnection(peripheral)
            potentialSensors.removeAll { $0.identifier == peripheral.identifier }
            
            // Resume scanning
            connectionState = .scanning
            centralManager?.scanForPeripherals(withServices: [libre2ServiceUUID], options: nil)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            logger.error("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case libre2WriteCharacteristicUUID:
                writeCharacteristic = characteristic
                logger.info("Found write characteristic")
                
            case libre2NotifyCharacteristicUUID:
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logger.info("Found notify characteristic")
            default:
                break
            }
        }
        
        // Check if we have both characteristics
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            delegate?.watchBluetoothManagerDidConnect(self, peripheral: peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        logger.info("Notification state updated for characteristic: \(characteristic.uuid)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else {
            logger.error("Error receiving data: \(error?.localizedDescription ?? "Unknown")")
            return
        }
        
        logger.info("Received data: \(value.count) bytes")
        delegate?.watchBluetoothManager(self, didReceiveData: value)
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchBluetoothManager: WKExtendedRuntimeSessionDelegate {
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        logger.info("Extended runtime session started")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        logger.warning("Extended runtime session will expire")
        // Request a new session
        setupExtendedSession()
        startExtendedSession()
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        logger.error("Extended runtime session invalidated. Reason: \(reason.rawValue), Error: \(error?.localizedDescription ?? "None")")
    }
}

// MARK: - Error Types

enum WatchBluetoothError: LocalizedError {
    case scanTimeout
    case connectionTimeout
    case connectionFailed
    case bluetoothPoweredOff
    
    var errorDescription: String? {
        switch self {
        case .scanTimeout:
            return "Bluetooth scan timeout"
        case .connectionTimeout:
            return "Connection timeout"
        case .connectionFailed:
            return "Failed to connect"
        case .bluetoothPoweredOff:
            return "Bluetooth is powered off"
        }
    }
}

// MARK: - WatchBluetoothDelegate Protocol

protocol WatchBluetoothDelegate: AnyObject {
    func watchBluetoothManagerDidConnect(_ manager: WatchBluetoothManager, peripheral: CBPeripheral)
    func watchBluetoothManagerDidDisconnect(_ manager: WatchBluetoothManager)
    func watchBluetoothManager(_ manager: WatchBluetoothManager, didReceiveData data: Data)
}