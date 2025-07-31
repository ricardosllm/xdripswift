//
//  ConnectionArbitrationManager.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import WatchConnectivity
import os.log

/// Manages connection arbitration between iPhone and Apple Watch
final class ConnectionArbitrationManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = ConnectionArbitrationManager()
    
    /// WCSession for communication with iPhone
    private let session: WCSession
    
    /// Bluetooth manager reference
    private weak var bluetoothManager: WatchBluetoothManager?
    
    /// Current arbitration state
    @Published var state: ArbitrationState = .idle
    
    /// iPhone connection status
    @Published var iPhoneConnected = false
    
    /// Logger
    private let logger = Logger(subsystem: "com.xdrip.watchapp", category: "ConnectionArbitration")
    
    /// Timer for connection request timeout
    private var requestTimer: Timer?
    
    // MARK: - Types
    
    enum ArbitrationState {
        case idle
        case iPhoneConnected
        case watchRequestingConnection
        case watchConnected
        case transitioning
    }
    
    enum ArbitrationMessage: String {
        case iPhoneWantsToConnect = "iPhoneWantsToConnect"
        case iPhoneDisconnected = "iPhoneDisconnected"
        case iPhonePriority = "iPhonePriority"
        case iPhoneDisconnecting = "iPhoneDisconnecting"
        case watchRequestingConnection = "watchRequestingConnection"
        case watchConnected = "watchConnected"
        case watchDisconnected = "watchDisconnected"
        case watchAcknowledgeDisconnect = "watchAcknowledgeDisconnect"
    }
    
    // MARK: - Initialization
    
    private override init() {
        self.session = WCSession.default
        super.init()
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Public Methods
    
    /// Configure with bluetooth manager
    func configure(bluetoothManager: WatchBluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }
    
    /// Request permission to connect
    func requestConnection() -> Bool {
        guard state == .idle || state == .iPhoneConnected else {
            logger.warning("Cannot request connection in state: \(String(describing: self.state))")
            return false
        }
        
        if iPhoneConnected {
            logger.info("iPhone is connected, Watch cannot connect")
            return false
        }
        
        state = .watchRequestingConnection
        sendMessage(.watchRequestingConnection)
        
        // Set timeout for response
        requestTimer?.invalidate()
        requestTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.handleRequestTimeout()
        }
        
        return true
    }
    
    /// Send arbitration message to iPhone
    func sendMessageToiPhone(_ message: String) {
        guard session.isReachable else {
            logger.warning("iPhone not reachable, cannot send: \(message)")
            return
        }
        
        let messageDict = ["arbitration": message]
        
        session.sendMessage(messageDict, replyHandler: nil) { [weak self] error in
            self?.logger.error("Failed to send arbitration message: \(error.localizedDescription)")
        }
    }
    
    /// Notify that Watch has connected
    func notifyConnected() {
        state = .watchConnected
        sendMessage(.watchConnected)
        requestTimer?.invalidate()
    }
    
    /// Notify that Watch has disconnected
    func notifyDisconnected() {
        state = .idle
        sendMessage(.watchDisconnected)
    }
    
    // MARK: - Private Methods
    
    private func sendMessage(_ message: ArbitrationMessage) {
        guard session.isReachable else {
            logger.warning("iPhone not reachable, cannot send: \(message.rawValue)")
            return
        }
        
        let messageDict = ["arbitration": message.rawValue]
        
        session.sendMessage(messageDict, replyHandler: nil) { [weak self] error in
            self?.logger.error("Failed to send arbitration message: \(error.localizedDescription)")
        }
        
        logger.info("Sent arbitration message: \(message.rawValue)")
    }
    
    private func handleRequestTimeout() {
        logger.info("Connection request timeout - assuming iPhone not connected")
        // If no response, assume we can connect
        state = .idle
        bluetoothManager?.handleiPhoneConnectionStateChange(false)
    }
    
    private func handleArbitrationMessage(_ message: ArbitrationMessage) {
        logger.info("Received arbitration message: \(message.rawValue)")
        
        switch message {
        case .iPhoneWantsToConnect:
            // iPhone wants to connect, we must disconnect
            iPhoneConnected = true
            state = .transitioning
            bluetoothManager?.disconnect()
            // Send acknowledgment
            sendMessage(.watchAcknowledgeDisconnect)
            state = .iPhoneConnected
            
        case .iPhoneDisconnected:
            // iPhone disconnected, we can connect
            iPhoneConnected = false
            state = .idle
            bluetoothManager?.handleiPhoneConnectionStateChange(false)
            
        case .iPhonePriority:
            // iPhone has priority but is not connected yet
            // Watch should not connect
            iPhoneConnected = false
            state = .idle
            requestTimer?.invalidate()
            logger.info("iPhone has priority, Watch will not connect")
            
        case .iPhoneDisconnecting:
            // iPhone is disconnecting for Watch priority
            // Wait a moment before connecting
            iPhoneConnected = false
            state = .transitioning
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.state = .idle
                self?.bluetoothManager?.handleiPhoneConnectionStateChange(false)
            }
            
        default:
            logger.warning("Unexpected arbitration message from iPhone: \(message.rawValue)")
        }
    }
}

// MARK: - WCSessionDelegate

extension ConnectionArbitrationManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let arbitrationString = message["arbitration"] as? String,
              let arbitrationMessage = ArbitrationMessage(rawValue: arbitrationString) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.handleArbitrationMessage(arbitrationMessage)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages that expect a reply
        if let arbitrationString = message["arbitration"] as? String,
           let arbitrationMessage = ArbitrationMessage(rawValue: arbitrationString) {
            DispatchQueue.main.async { [weak self] in
                self?.handleArbitrationMessage(arbitrationMessage)
            }
            replyHandler(["status": "received"])
        } else {
            replyHandler(["status": "unknown message"])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle sensor activation data
        if let sensorData = applicationContext["libre2SensorData"] as? [String: Any] {
            logger.info("Received sensor activation data")
            // This will be handled by the main Watch app
            NotificationCenter.default.post(
                name: .libre2SensorDataReceived,
                object: nil,
                userInfo: sensorData
            )
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        logger.info("iPhone reachability changed: \(session.isReachable)")
        
        if !session.isReachable {
            // iPhone is not reachable, we might be able to connect
            DispatchQueue.main.async { [weak self] in
                self?.iPhoneConnected = false
                if self?.state == .iPhoneConnected {
                    self?.state = .idle
                    self?.bluetoothManager?.handleiPhoneConnectionStateChange(false)
                }
            }
        }
    }
}