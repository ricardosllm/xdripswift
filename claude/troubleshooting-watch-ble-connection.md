# Troubleshooting: Watch BLE Connection to Libre 2

## Current Status

### ✅ Working:
1. **Sensor data sync**: Watch successfully receives sensor configuration (UID, serial number, unlock code)
2. **UI feedback**: Visual indicators show when scanning
3. **Arbitration**: iPhone properly disconnects when Watch requests connection
4. **Threading**: No more "publishing from background thread" errors

### ❌ Not Working:
1. **BLE Discovery**: Watch scan times out without finding any peripherals
2. **Extended Runtime Session**: Failing with "client not approved" error

## Console Log Analysis

### iPhone Logs:
```
API MISUSE: Cancelling connection for unused peripheral <CBPeripheral: 0x10b65b1e0, identifier = ED8D5E87-B8FB-5897-794C-A7B101736A22, name = ABBOTT3MH01CEKWG0, mtu = 23, state = connecting>
```
- Shows sensor name format: "ABBOTT3MH01CEKWG0"
- iPhone is having issues maintaining peripheral reference

### Watch Logs:
```
Configured sensor - UID: 785cb61500a407e0, Unlock: 10
Starting scan for sensor with full serial: 3MH01CEKWG0
Performing BLE scan
Scan timeout reached
```
- Sensor data received correctly
- BLE scan starts but finds no peripherals
- Extended runtime session fails: "client not approved"

## Root Cause Analysis

### 1. Libre 2 BLE Advertising Behavior
- Libre 2 sensors only advertise briefly after NFC activation
- Once connected to a device, they stop advertising
- Sensor needs to be "unlocked" via NFC to enable BLE streaming

### 2. Watch App Limitations
- Extended runtime session failing suggests background BLE might not be properly configured
- Watch apps have stricter BLE permissions than iPhone apps

### 3. Timing Issues
- Even though iPhone disconnects, sensor might not immediately start advertising again
- There might be a window where sensor is not connected but also not advertising

## Potential Solutions

### 1. Verify NFC Activation (Most Likely Issue)
The Libre 2 sensor requires NFC activation to enable BLE streaming. The Watch cannot perform NFC, so:
- User must scan sensor with iPhone first to activate BLE
- This activation is time-limited (usually 5-10 minutes)
- Watch must connect during this window

### 2. Improve Discovery Logic
- Try scanning without service UUID filter initially
- Implement retry logic with delays
- Add manual "Activate Sensor" instruction for user

### 3. Fix Extended Runtime Session
The error "client not approved" suggests the Watch app might need additional entitlements or Info.plist entries for background BLE.

### 4. Alternative Approach
Instead of direct BLE connection, consider:
- iPhone remains connected and relays data to Watch
- Watch only connects when iPhone app is terminated/background

## Recommended Next Steps

1. **User Action Required**:
   - Scan Libre 2 sensor with iPhone NFC to activate BLE
   - Immediately trigger Watch connection within activation window
   - Ensure iPhone Bluetooth is not connected during this process

2. **Code Improvements**:
   - Add user instructions about NFC activation requirement
   - Implement better error messages explaining the process
   - Add retry mechanism with user-friendly feedback

3. **Testing**:
   - Test with freshly NFC-activated sensor
   - Monitor if sensor appears in scan after NFC activation
   - Check if removing/re-pairing Watch helps with permissions

## Technical Notes

- Libre 2 advertises with name: "ABBOTT" + serial number
- Service UUID: FDE3
- Requires unlock payload based on sensor UID and activation time
- BLE connection window is limited after NFC activation