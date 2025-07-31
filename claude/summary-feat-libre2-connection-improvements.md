# Libre 2 Connection Improvements Summary

## Key Changes Made

### 1. Removed RSSI Filtering (Most Important!)
- **Before**: Only connected to devices with RSSI > -85 dBm
- **After**: Connects to ALL unnamed devices regardless of signal strength
- **Impact**: Won't miss sensors with weak signals

### 2. Parallel Connection Strategy
- **Before**: Stopped scanning after finding one potential device
- **After**: Continues scanning while connecting to multiple devices
- **Impact**: Faster discovery by checking multiple devices simultaneously

### 3. Extended Scan Timeout
- **Before**: 30 seconds timeout
- **After**: 60 seconds timeout with retry logic
- **Impact**: More time to find sensor within 5-minute window

### 4. Retry Logic
- **Before**: Failed after first timeout
- **After**: Retries up to 3 times if no sensor found
- **Impact**: Much higher success rate

### 5. Improved iPhone Disconnection
- **Before**: Simple disconnect call with 1-second wait
- **After**: 
  - Notifies Watch immediately to prepare
  - Waits 2 seconds for proper disconnection
  - Re-enables notifications for UI feedback
- **Impact**: Better coordination between devices

### 6. More Aggressive Discovery
- **Before**: Only checked devices with specific name patterns
- **After**: 
  - Connects to all unnamed devices
  - Connects to devices with any weak signal
  - Checks devices with just serial number as name
- **Impact**: Won't miss sensors that don't advertise properly

## Code Quality Improvements

1. **Better Error Handling**: Retry instead of immediate failure
2. **Progress Tracking**: Using `scanAttempts` counter
3. **Cleaner State Management**: Reset attempts on new scan
4. **Improved Logging**: More detailed status messages

## What This Solves

### Primary Issue: Missing Sensors
The Libre 2 sensor often:
- Doesn't advertise its name (shows as "Unknown")
- Has variable/weak signal strength
- Doesn't advertise the FDE3 service UUID

Our changes ensure we try to connect to EVERY possible device and verify if it's a Libre 2 by checking services after connection.

### Time Window Optimization
With only 5 minutes after NFC activation:
- Immediate Watch notification (no delay)
- Parallel device checking
- Extended timeouts
- Automatic retries

## Testing the Improvements

1. Follow the handover process again
2. Watch should now try connecting to all "Unknown" devices
3. Should see in logs: "Found unnamed device with RSSI X, connecting to verify if Libre 2"
4. Connection attempts continue even while checking other devices

## Future Enhancements (If Still Issues)

1. **Pre-warm Bluetooth**: Start Watch scanning before NFC
2. **Connection Queue**: Manage multiple parallel connections better
3. **Smart Filtering**: Learn device characteristics over time
4. **Background Handover**: Complete process even if app backgrounded

## Summary

The key insight was that Libre 2 sensors often don't advertise their identity properly. Instead of trying to identify them before connecting, we now connect first and verify afterwards. This "connect to everything" approach is more aggressive but necessary given the short 5-minute window and unpredictable sensor behavior.