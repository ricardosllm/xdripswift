//
//  Libre2ConnectionView.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WatchConnectivity

struct Libre2ConnectionView: View {
    @EnvironmentObject var watchState: WatchStateModel
    @StateObject private var glucoseManager = Libre2GlucoseManager.shared
    @StateObject private var bluetoothManager = WatchBluetoothManager.shared
    @StateObject private var arbitrationManager = ConnectionArbitrationManager.shared
    
    @State private var showingSettings = false
    @State private var readingInterval = 5
    @State private var scanFeedback = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Connection Status Card
                connectionStatusCard
                
                // Sensor Info Card
                if glucoseManager.sensorInfo != nil {
                    sensorInfoCard
                }
                
                // Connection Control
                connectionControlCard
                
                // Settings Button
                Button(action: { showingSettings.toggle() }) {
                    Label("Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Libre 2 Direct")
        .sheet(isPresented: $showingSettings) {
            settingsView
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: connectionIcon)
                    .foregroundColor(connectionColor)
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: bluetoothManager.connectionState == .scanning)
                
                VStack(alignment: .leading) {
                    Text("Connection Status")
                        .font(.headline)
                    Text(bluetoothManager.connectionState.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if bluetoothManager.connectionState == .scanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if let error = bluetoothManager.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Data Source Indicator
            HStack {
                Text("Data Source:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                    Text(glucoseManager.dataSource.description)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
            }
            
            // Arbitration State
            if arbitrationManager.state != .idle {
                HStack {
                    Text("Priority:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(arbitrationStateText)
                        .font(.caption)
                        .foregroundColor(arbitrationStateColor)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    // MARK: - Sensor Info Card
    
    private var sensorInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Sensor Info")
                        .font(.headline)
                    if let serial = glucoseManager.sensorInfo?.serialNumber.suffix(6) {
                        Text("...\(serial)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let sensorInfo = glucoseManager.sensorInfo {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Age")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(sensorInfo.ageInDays) days")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(sensorInfo.remainingDays) days")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(sensorInfo.remainingDays <= 1 ? .red : .primary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    // MARK: - Connection Control Card
    
    private var connectionControlCard: some View {
        VStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled") },
                set: { glucoseManager.setDirectConnectionEnabled($0) }
            )) {
                Label("Direct Connection", systemImage: "applewatch.radiowaves.left.and.right")
            }
            .tint(.green)
            
            if UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled") {
                HStack {
                    Text("Reading every")
                        .font(.caption)
                    Text("\(readingInterval) min")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    // MARK: - Settings View
    
    private var settingsView: some View {
        NavigationView {
            Form {
                Section(header: Text("Reading Interval")) {
                    Picker("Interval", selection: $readingInterval) {
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("3 minutes").tag(3)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                    }
                    .onChange(of: readingInterval) { oldValue, newValue in
                        glucoseManager.setReadingInterval(newValue)
                    }
                }
                
                Section(header: Text("Debug")) {
                    if let sensorInfo = glucoseManager.sensorInfo {
                        LabeledContent("Sensor UID", value: sensorInfo.uid.hexEncodedString())
                        LabeledContent("Patch Info", value: sensorInfo.patchInfo.hexEncodedString())
                        LabeledContent("Serial Number", value: sensorInfo.serialNumber)
                        LabeledContent("Unlock Code", value: String(sensorInfo.unlockCode))
                        LabeledContent("Activation Date", value: sensorInfo.activationDate.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Sensor Age", value: "\(sensorInfo.ageInDays) days")
                    } else {
                        Text("No sensor data available")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    LabeledContent("BLE State", value: bluetoothManager.connectionState.rawValue)
                    LabeledContent("Arbitration", value: "\(arbitrationManager.state)")
                    LabeledContent("Direct Connection", value: UserDefaults.standard.bool(forKey: "libre2DirectToWatchEnabled") ? "Enabled" : "Disabled")
                    
                    // Add button to manually check for sensor data
                    Button(action: {
                        // Check UserDefaults for sensor data
                        if let sensorData = UserDefaults.standard.data(forKey: "libre2SensorInfo"),
                           let info = try? JSONDecoder().decode(Libre2GlucoseManager.SensorInfo.self, from: sensorData) {
                            print("Found stored sensor data: \(info.serialNumber)")
                        } else {
                            print("No stored sensor data found")
                        }
                        
                        // Check application context
                        let context = WCSession.default.receivedApplicationContext
                        if let sensorData = context["libre2SensorData"] as? [String: Any] {
                            print("Found sensor data in application context: \(sensorData)")
                            
                            // Try to process it manually
                            NotificationCenter.default.post(
                                name: .libre2SensorDataReceived,
                                object: nil,
                                userInfo: sensorData
                            )
                            print("Posted notification to process sensor data")
                        } else {
                            print("No sensor data in application context")
                        }
                        
                        // Request update from iPhone
                        if WCSession.default.isReachable {
                            WCSession.default.sendMessage(["requestWatchUpdate": "watchState"], replyHandler: nil, errorHandler: { error in
                                print("Error requesting update: \(error)")
                            })
                            print("Requested update from iPhone")
                        }
                    }) {
                        Label("Check Sensor Data", systemImage: "magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    
                    // Add button to manually trigger BLE scan
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: {
                            if let sensorInfo = glucoseManager.sensorInfo {
                                scanFeedback = "Starting scan..."
                                print("Manually triggering BLE scan for sensor: \(sensorInfo.serialNumber)")
                                bluetoothManager.stopScanning() // Stop any existing scan
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    bluetoothManager.startScanning(sensorSerialNumber: sensorInfo.serialNumber)
                                    
                                    // Update feedback after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        if bluetoothManager.connectionState == .scanning {
                                            scanFeedback = "Scanning for ABBOTT\(sensorInfo.serialNumber)..."
                                        } else if bluetoothManager.connectionState == .connected {
                                            scanFeedback = "Connected!"
                                        } else {
                                            scanFeedback = "Scan started. Check BLE State above."
                                        }
                                    }
                                    
                                    // Clear feedback after 5 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        scanFeedback = ""
                                    }
                                }
                            } else {
                                scanFeedback = "No sensor info available"
                                print("No sensor info available for BLE scan")
                                
                                // Clear feedback after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    scanFeedback = ""
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: bluetoothManager.connectionState == .scanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                    .foregroundColor(bluetoothManager.connectionState == .scanning ? .orange : .primary)
                                Text(bluetoothManager.connectionState == .scanning ? "Scanning..." : "Start BLE Scan")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .disabled(glucoseManager.sensorInfo == nil)
                        
                        if !scanFeedback.isEmpty {
                            Text(scanFeedback)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
        .onAppear {
            readingInterval = UserDefaults.standard.integer(forKey: "watchReadingInterval")
            if readingInterval == 0 { readingInterval = 5 }
        }
    }
    
    // MARK: - Helper Properties
    
    private var connectionIcon: String {
        switch bluetoothManager.connectionState {
        case .idle:
            return "antenna.radiowaves.left.and.right.slash"
        case .scanning:
            return "antenna.radiowaves.left.and.right"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "antenna.radiowaves.left.and.right"
        case .disconnecting:
            return "antenna.radiowaves.left.and.right.slash"
        case .waitingForiPhone:
            return "iphone.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private var connectionColor: Color {
        switch bluetoothManager.connectionState {
        case .idle:
            return .gray
        case .scanning, .connecting:
            return .orange
        case .connected:
            return .green
        case .disconnecting:
            return .orange
        case .waitingForiPhone:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var arbitrationStateText: String {
        switch arbitrationManager.state {
        case .idle:
            return "Ready"
        case .iPhoneConnected:
            return "iPhone has priority"
        case .watchRequestingConnection:
            return "Requesting..."
        case .watchConnected:
            return "Watch connected"
        case .transitioning:
            return "Switching..."
        }
    }
    
    private var arbitrationStateColor: Color {
        switch arbitrationManager.state {
        case .idle:
            return .gray
        case .iPhoneConnected:
            return .blue
        case .watchRequestingConnection:
            return .orange
        case .watchConnected:
            return .green
        case .transitioning:
            return .orange
        }
    }
}

struct Libre2ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        Libre2ConnectionView()
            .environmentObject(WatchStateModel())
    }
}