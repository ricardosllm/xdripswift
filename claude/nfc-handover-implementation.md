# Libre 2 NFC Handover Implementation

## Overview

This document describes the implementation of the NFC handover feature for Libre 2 sensors, which allows users to initiate direct Bluetooth LE connections from Apple Watch to their sensor.

## Problem Statement

Libre 2 sensors require NFC activation to enable Bluetooth LE advertising. This advertising window is limited to approximately 5-10 minutes after NFC activation. During this window, devices can connect directly to the sensor via BLE. The challenge is to provide a seamless user experience for handing over the connection from iPhone to Apple Watch.

## Solution

### User Flow

1. User navigates to Settings → Apple Watch → "Scan Sensor for Watch Handover"
2. A progress view controller appears showing the handover steps
3. iPhone disconnects from the sensor
4. User is prompted to scan the sensor with NFC
5. After NFC scan, BLE advertising is activated
6. A countdown timer shows the remaining BLE window (5 minutes)
7. Watch attempts to connect to the sensor
8. Progress updates show each stage of the process

### Technical Implementation

#### 1. UI Components

**Libre2HandoverViewController**
- Full-screen progress view with stages
- Real-time status updates
- Countdown timer for BLE activation window
- Visual feedback for each stage:
  - Disconnecting iPhone
  - Waiting for NFC
  - NFC scanning
  - BLE activated
  - Watch connecting
  - Completed/Failed

#### 2. Handover Process

**BluetoothPeripheralManager.scanForLibre2ForWatchHandover()**
```swift
1. Disconnect iPhone from sensor
2. Post notification: libre2iPhoneDisconnectedForHandover
3. Notify Watch of disconnection
4. Post notification: libre2NFCScanStarted
5. Trigger NFC scan
6. Post notification: libre2NFCScanCompleted
```

#### 3. Notification Flow

**iPhone → Watch**
- "iPhoneDisconnected" - iPhone has disconnected from sensor
- Status updates via application context

**Watch → iPhone**
- "watchConnecting" - Watch is attempting connection
- "watchConnected" - Watch successfully connected
- "watchConnectionFailed" - Connection attempt failed
- "watchDisconnected" - Watch disconnected from sensor

#### 4. Connection Status Tracking

**WatchManager+Libre2.swift**
- Handles arbitration messages from Watch
- Posts UI notifications for progress updates
- Maintains connection state

**ConnectionArbitrationManager (Watch)**
- Manages connection requests
- Sends status updates to iPhone
- Handles priority-based arbitration

## Key Files Modified

### iPhone App

1. **SettingsViewAppleWatchSettingsViewModel.swift**
   - Added `scanForWatchHandover` setting case
   - UI for initiating handover

2. **RootViewController.swift**
   - Added `handleScanLibre2ForWatchHandover()` method
   - Presents `Libre2HandoverViewController`

3. **Libre2HandoverViewController.swift** (NEW)
   - Progress UI for handover process
   - Handles notification updates
   - Shows countdown timer

4. **BluetoothPeripheralManager.swift**
   - Added handover methods
   - Posts progress notifications

5. **WatchManager+Libre2.swift**
   - Handles Watch status messages
   - Posts UI update notifications

### Watch App

1. **WatchBluetoothManager.swift**
   - Sends "watchConnecting" status
   - Fixed threading issues

2. **WatchLibre2BluetoothDelegate.swift**
   - Sends "watchConnected"/"watchDisconnected" status

3. **ConnectionArbitrationManager.swift**
   - Added `sendMessageToiPhone()` public method

## Build Instructions

To test the NFC handover feature:

1. Add `Libre2HandoverViewController.swift` to the xdrip target in Xcode
2. Build and run on physical iPhone with NFC capability
3. Ensure Apple Watch app is installed
4. Navigate to Settings → Apple Watch → "Scan Sensor for Watch Handover"
5. Follow on-screen instructions

## Known Limitations

1. **BLE Window**: Only 5-10 minutes after NFC activation
2. **NFC Required**: iPhone must perform NFC scan (Watch cannot)
3. **Timing Critical**: User must move Watch near sensor quickly after NFC scan
4. **One Device Only**: Sensor can only connect to one device at a time

## Future Improvements

1. **Auto-retry**: Implement automatic retry logic if connection fails
2. **Background Handover**: Allow handover to complete in background
3. **Extended Session**: Improve Watch extended runtime session for longer connection attempts
4. **Smart Scheduling**: Schedule handovers based on user patterns

## Testing Checklist

- [ ] iPhone disconnects from sensor
- [ ] NFC scan prompt appears
- [ ] Progress UI updates correctly
- [ ] Countdown timer displays
- [ ] Watch receives disconnection notification
- [ ] Watch attempts connection
- [ ] Status updates reach iPhone
- [ ] Success/failure states handled properly
- [ ] Can cancel at any stage

## Summary

The NFC handover feature provides a user-friendly way to transfer Libre 2 sensor connections from iPhone to Apple Watch. While the process requires user interaction due to technical limitations (NFC activation requirement), the implementation provides clear visual feedback and guidance throughout the process.