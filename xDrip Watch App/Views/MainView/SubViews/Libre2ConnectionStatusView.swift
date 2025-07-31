//
//  Libre2ConnectionStatusView.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Small status view showing Libre 2 connection state
struct Libre2ConnectionStatusView: View {
    @StateObject private var glucoseManager = Libre2GlucoseManager.shared
    @StateObject private var bluetoothManager = WatchBluetoothManager.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: connectionIcon)
                .font(.caption2)
                .foregroundColor(connectionColor)
            
            Text(glucoseManager.dataSource.description)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if bluetoothManager.connectionState == .scanning ||
               bluetoothManager.connectionState == .connecting {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var connectionIcon: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return "antenna.radiowaves.left.and.right"
        case .scanning, .connecting:
            return "antenna.radiowaves.left.and.right"
        case .waitingForiPhone:
            return "iphone.radiowaves.left.and.right"
        default:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    private var connectionColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return .green
        case .scanning, .connecting:
            return .orange
        case .waitingForiPhone:
            return .blue
        case .error:
            return .red
        default:
            return .gray
        }
    }
}