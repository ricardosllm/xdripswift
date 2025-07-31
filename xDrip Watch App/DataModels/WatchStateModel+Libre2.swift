//
//  WatchStateModel+Libre2.swift
//  xDrip Watch App
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

extension WatchStateModel {
    
    // MARK: - Libre 2 Properties
    
    /// Check if we're using direct Watch connection
    var isUsingDirectConnection: Bool {
        Libre2GlucoseManager.shared.dataSource == .watchDirect
    }
    
    /// Get Libre 2 connection status
    var libre2ConnectionStatus: String {
        if !libre2DirectConnectionEnabled { return "" }
        
        switch WatchBluetoothManager.shared.connectionState {
        case .idle:
            return "Idle"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .waitingForiPhone:
            return "iPhone Priority"
        case .error:
            return "Error"
        }
    }
    
    /// Check if Libre 2 direct connection is enabled
    var libre2DirectConnectionEnabled: Bool {
        UserDefaults.standard.bool(forKey: "watchDirectConnectionEnabled")
    }
    
    // MARK: - Integration Methods
    
    /// Setup Libre 2 integration
    func setupLibre2Integration() {
        // Subscribe to Libre 2 glucose updates
        Libre2GlucoseManager.shared.$currentGlucose
            .combineLatest(
                Libre2GlucoseManager.shared.$lastReadingDate,
                Libre2GlucoseManager.shared.$deltaChange,
                Libre2GlucoseManager.shared.$trendArrow
            )
            .sink { [weak self] glucose, date, delta, trend in
                guard let self = self,
                      let date = date,
                      glucose > 0,
                      Libre2GlucoseManager.shared.dataSource == .watchDirect else { return }
                
                // Update our state with Libre 2 data
                self.updateFromLibre2(glucose: glucose, date: date, delta: delta, trend: trend)
            }
            .store(in: &cancellables)
        
        // Subscribe to connection state changes
        WatchBluetoothManager.shared.$connectionState
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Update state from Libre 2 data
    private func updateFromLibre2(glucose: Int, date: Date, delta: Int, trend: Libre2GlucoseManager.TrendArrow) {
        // Update bg values
        bgReadingValues = [Double(glucose)]
        bgReadingDates = [date]
        bgReadingDatesAsDouble = [date.timeIntervalSince1970]
        
        // Update delta
        deltaValueInUserUnit = Double(delta)
        
        // Update trend arrow
        switch trend {
        case .doubleUp:
            slopeOrdinal = 1
        case .singleUp:
            slopeOrdinal = 2
        case .fortyFiveUp:
            slopeOrdinal = 3
        case .flat:
            slopeOrdinal = 4
        case .fortyFiveDown:
            slopeOrdinal = 5
        case .singleDown:
            slopeOrdinal = 6
        case .doubleDown:
            slopeOrdinal = 7
        }
        
        // Update last updated strings
        lastUpdatedTextString = "Direct: "
        lastUpdatedTimeString = date.formatted(date: .omitted, time: .shortened)
        lastUpdatedTimeAgoString = date.daysAndHoursAgo(appendAgo: true)
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    /// Process Libre 2 sensor data from iPhone
    func processLibre2SensorData(_ data: [String: Any]) {
        // This is handled by ConnectionArbitrationManager
        // which posts a notification that Libre2GlucoseManager observes
    }
    
    // MARK: - UI Helpers
    
    /// Get connection source icon
    func connectionSourceIcon() -> Image? {
        switch Libre2GlucoseManager.shared.dataSource {
        case .none:
            return nil
        case .iPhone:
            return Image(systemName: "iphone")
        case .watchDirect:
            return Image(systemName: "applewatch")
        }
    }
    
    /// Get connection source color
    func connectionSourceColor() -> Color {
        switch Libre2GlucoseManager.shared.dataSource {
        case .none:
            return .gray
        case .iPhone:
            return .blue
        case .watchDirect:
            return .green
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}