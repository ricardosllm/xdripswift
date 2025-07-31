# Libre 2 Direct Apple Watch Connection - Implementation Summary

## Overview
This document summarizes the work done to implement direct Bluetooth connection from Apple Watch to Libre 2 sensors, bypassing the iPhone when needed. This feature allows the Watch to independently collect glucose data when the iPhone is not nearby.

## Context
- **Date**: July 2025
- **Sensor**: Libre 2 Plus EU (11-character serial numbers)
- **Current Status**: Core functionality implemented but needs testing with watchOS 26
- **Branch**: `bluetooth-direct`

## What We Implemented

### 1. Core Bluetooth Infrastructure on Watch

#### Watch Bluetooth Manager (`WatchBluetoothManager.swift`)
- Central manager for BLE operations on Watch
- Handles scanning, connection, and data reception
- Connection states: idle, scanning, connecting, connected, disconnecting, waitingForiPhone, error
- Implements 5-minute BLE window after NFC activation

#### Libre 2 Bluetooth Delegate (`WatchLibre2BluetoothDelegate.swift`)
- Processes Libre 2 BLE packets
- Sends unlock payload after connection (critical for data streaming)
- Decrypts glucose data using existing Libre2 decryption algorithms
- Handles sensor UID, patch info, and unlock codes

#### Connection Arbitration Manager (`ConnectionArbitrationManager.swift`)
- Coordinates between iPhone and Watch to prevent conflicts
- Implements priority system: iPhone, Watch, or Auto
- Handles handover messaging via WatchConnectivity

### 2. iPhone-Watch Handover Process

#### Handover View Controller (`Libre2HandoverViewController.swift`)
- Visual UI for guiding users through the handover process
- Stages: Disconnecting → NFC Scan → Sending Sensor Data → BLE Activated → Watch Connecting → Complete
- Shows 5-minute countdown for BLE window
- Provides clear feedback at each stage

#### Handover Flow
1. iPhone disconnects from sensor (sets `shouldconnect = false`)
2. User performs NFC scan to activate 5-minute BLE window
3. iPhone shares sensor data with Watch (UID, patch info, unlock code, activation date)
4. Watch connects to sensor using shared credentials
5. Watch sends unlock payload to start data streaming

### 3. Settings and Configuration

#### Developer Settings (iPhone)
- "Enable Libre 2 Direct to Watch" toggle
- "Prioritize Apple Watch" with options: iPhone Priority, Watch Priority, Auto
- "Libre 2 to Watch Handover" button to initiate process

#### Watch Settings Sync
- Settings automatically sync during handover
- Stored in UserDefaults and WatchConnectivity application context

### 4. Data Flow

#### Glucose Data Manager (`Libre2GlucoseManager.swift`)
- Singleton managing glucose readings on Watch
- Tracks data source: none, iPhone, or watchDirect
- Publishes updates for UI consumption

#### State Management (`WatchStateModel.swift`)
- Extended to handle Libre 2 sensor data
- Processes sensor activation info
- Manages UI updates on main thread

## Critical Implementation Details

### 1. Unlock Payload Requirement
```swift
// Must send unlock payload immediately after connection
private func sendUnlockPayload(to manager: WatchBluetoothManager) {
    let unlockPayload = streamingUnlockPayload(
        sensorUID: sensorUID,
        info: patchInfo,
        enableTime: unlockCode,
        unlockCount: UInt16(unlockCount)
    )
    manager.sendData(Data(unlockPayload))
}
```

### 2. BLE Characteristics
- Service UUID: `FDE3` (Libre 2 data service)
- Read characteristic: `F002` (notifications for glucose data)
- Write characteristic: `F001` (for unlock payload)

### 3. Sensor Data Structure
```swift
let sensorData: [String: Any] = [
    "uid": uid.hexEncodedString(),
    "patchInfo": patchInfo.hexEncodedString(),
    "serialNumber": serialNumber,
    "activationDate": activationDate.timeIntervalSince1970,
    "unlockCode": unlockCode,
    "unlockCount": unlockCount
]
```

## Issues Encountered and Fixes

### 1. Connection Dropping
- **Issue**: Watch showed "connected" briefly then "scanning"
- **Fix**: Added unlock payload sending immediately after connection

### 2. iPhone Not Disconnecting
- **Issue**: iPhone continued scanning after handover
- **Fix**: Set `shouldconnect = false` in Core Data before disconnecting

### 3. Sensor Age Showing 0
- **Issue**: Watch displayed sensor age as 0 instead of actual age (7d8h)
- **Root Cause**: iPhone was using wrong date field
  - `activeSensorStartDate` was nil
  - Should use `sensorTimeInMinutes` from Libre2 object
- **Attempted Fix**: Modified to calculate from `sensorTimeInMinutes`
- **Status**: Needs further testing

### 4. Threading Warnings
- **Issue**: UI updates from background thread
- **Fix**: Wrapped UI updates in `DispatchQueue.main.async`

### 5. Serial Number Validation
- **Issue**: Libre 2 Plus has 11 characters, not 10
- **Fix**: Updated validation to accept both lengths

## Remaining Work

### 1. Sensor Age Synchronization
The sensor activation date is not properly syncing. The iPhone stores sensor age as `sensorTimeInMinutes` but needs to convert this to an activation date for the Watch.

### 2. Testing Requirements
- Test with actual Libre 2 sensor and NFC activation
- Verify 5-minute BLE window timing
- Test connection stability over time
- Verify glucose data accuracy

### 3. Future Enhancements
- Auto-reconnection after Watch goes out of range
- Background refresh for complications
- Historical data sync when reconnecting
- Support for multiple sensor types

## Important Code Locations

### iPhone App
- `/xdrip/Managers/BluetoothPeripheral/BluetoothPeripheralManager+Libre2Watch.swift` - Handover logic
- `/xdrip/Managers/Watch/WatchManager+Libre2.swift` - Watch communication
- `/xdrip/View Controllers/Libre2HandoverViewController.swift` - Handover UI

### Watch App
- `/xDrip Watch App/Managers/Bluetooth/WatchBluetoothManager.swift` - BLE management
- `/xDrip Watch App/Managers/Bluetooth/WatchLibre2BluetoothDelegate.swift` - Libre 2 protocol
- `/xDrip Watch App/DataModels/WatchStateModel.swift` - State management

## Testing Notes

When testing, ensure:
1. Both apps are built and deployed (iPhone and Watch)
2. Developer settings are enabled on iPhone
3. "Enable Libre 2 Direct to Watch" is ON
4. Watch app is open during handover
5. NFC scan is performed correctly
6. Monitor logs for connection status

## Next Steps

1. Fix sensor age synchronization issue
2. Test with watchOS 26 when available
3. Add robust error handling for edge cases
4. Implement automatic reconnection logic
5. Add unit tests for critical components

## References
- Libre 2 BLE Protocol: See `/claude/sources/` for reverse-engineered protocol details
- Original feature plan: `/claude/plan-feat-ble.md`
- Connection stability improvements: `/claude/summary-feat-libre2-connection-stability.md`