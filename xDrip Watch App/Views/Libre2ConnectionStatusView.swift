//
//  Libre2ConnectionStatusView.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Compact connection status indicator for main views
struct Libre2ConnectionStatusView: View {
    @StateObject private var glucoseManager = Libre2GlucoseManager.shared
    @StateObject private var bluetoothManager = WatchBluetoothManager.shared
    
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Connection indicator
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
                .font(.caption2)
            
            // Data source
            if glucoseManager.dataSource != .none {
                Text(glucoseManager.dataSource == .watchDirect ? "Direct" : "iPhone")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            Libre2ConnectionView()
        }
    }
    
    private var connectionIcon: String {
        guard UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled") else {
            return "antenna.radiowaves.left.and.right.slash"
        }
        
        switch bluetoothManager.connectionState {
        case .connected:
            return "dot.radiowaves.left.and.right"
        case .scanning, .connecting:
            return "antenna.radiowaves.left.and.right"
        default:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    private var connectionColor: Color {
        guard UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled") else {
            return .gray
        }
        
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        case .scanning, .connecting:
            return .orange
        case .error:
            return .red
        default:
            return .gray
        }
    }
}

/// Minimal connection dot for complications
struct Libre2ConnectionDot: View {
    @StateObject private var bluetoothManager = WatchBluetoothManager.shared
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
    }
    
    private var dotColor: Color {
        guard UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled") else {
            return .clear
        }
        
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        case .scanning, .connecting:
            return .orange
        default:
            return .gray
        }
    }
}