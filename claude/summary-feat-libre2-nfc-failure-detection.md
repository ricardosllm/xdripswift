# Libre 2 NFC Scan Failure Detection Implementation

## Problem
The handover process would continue even when NFC scan failed, leading to the Watch attempting to connect without proper sensor activation. This would always fail because:
1. Libre 2 sensors only advertise over BLE for 5-10 minutes after NFC activation
2. Without successful NFC scan, the sensor doesn't start BLE advertising
3. The handover would proceed anyway, wasting the user's time

## Solution
Added proper NFC scan result detection using the existing `LibreNFCDelegate` protocol:

### 1. NFC Scan Result Tracking
The `CGMLibre2Transmitter` already implements `nfcScanResult(successful: Bool)` which updates:
- `UserDefaults.standard.nfcScanSuccessful = true` on success
- `UserDefaults.standard.nfcScanFailed = true` on failure

### 2. Handover Process Updates
Modified `BluetoothPeripheralManager.scanForLibre2ForWatchHandover()` to:
- Reset both flags before starting NFC scan
- Set up UserDefaults observers to watch for changes
- Only proceed with handover if `nfcScanSuccessful` becomes true
- Cancel handover if `nfcScanFailed` becomes true
- Add 30-second timeout for NFC scan

### 3. User Feedback
The handover view controller already handles the notification properly:
- Shows error state with message on NFC failure
- Allows user to retry or cancel

## Code Changes

### BluetoothPeripheralManager.swift
```swift
// Reset flags before scan
UserDefaults.standard.nfcScanSuccessful = false
UserDefaults.standard.nfcScanFailed = false

// Start NFC scan
_ = transmitter.startScanning()

// Set up observers for scan result
nfcSuccessObserver = NotificationCenter.default.addObserver(
    forName: UserDefaults.didChangeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    if UserDefaults.standard.nfcScanSuccessful {
        // Proceed with handover
        trace("NFC scan successful, proceeding with handover", ...)
        removeObservers()
        
        // Send sensor data to Watch
        NotificationCenter.default.post(
            name: Notification.Name("libre2ShouldShareSensorDataWithWatch"),
            object: nil
        )
        
        // Continue handover after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(
                name: Notification.Name("libre2NFCScanCompleted"),
                object: nil,
                userInfo: ["success": true, "activationTime": Date()]
            )
        }
    }
}

// Similar observer for failure case
nfcFailureObserver = NotificationCenter.default.addObserver(...) {
    if UserDefaults.standard.nfcScanFailed {
        trace("NFC scan failed, cancelling handover", ...)
        removeObservers()
        
        NotificationCenter.default.post(
            name: Notification.Name("libre2NFCScanCompleted"),
            object: nil,
            userInfo: ["success": false, "error": "NFC scan failed"]
        )
    }
}
```

## How LibreNFC Reports Results

From `LibreNFC.swift`:
```swift
func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    // ... error handling ...
    
    if nfcScanSuccessful {
        // Successful scan with valid data
        libreNFCDelegate?.nfcScanResult(successful: true)
        libreNFCDelegate?.nfcScanExpectedDevice(serialNumber: serialNumber, macAddress: macAddress)
        libreNFCDelegate?.startBLEScanning()
    } else {
        // Failed scan
        AudioServicesPlaySystemSound(1107) // Failed vibration
        libreNFCDelegate?.nfcScanResult(successful: false)
    }
}
```

The scan is considered successful only when:
1. NFC tag is detected
2. System info and patch info are retrieved
3. BLE streaming is successfully enabled
4. Serial number is extracted

## User Experience
1. User starts handover in iPhone settings
2. iPhone disconnects from sensor
3. NFC scan prompt appears
4. If scan fails:
   - Error vibration plays
   - Handover view shows "NFC scan failed" error
   - User can retry or cancel
5. If scan succeeds:
   - Success message shown
   - Sensor data sent to Watch
   - Watch begins connection attempt

## Testing
- Test with successful NFC scan → handover proceeds
- Test with canceled NFC scan → handover canceled with error
- Test with NFC timeout → handover canceled with timeout error
- Test with failed NFC read → handover canceled with error