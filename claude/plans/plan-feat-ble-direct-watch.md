# Libre 2 Plus EU Direct Apple Watch Connection Implementation Plan

## Overview
Enable direct Bluetooth LE connection between Libre 2 Plus EU sensors and Apple Watch in xdrip4ios, allowing glucose readings without requiring an iPhone connection.

## Current Architecture Analysis

### xdripswift
- **Watch Communication**: Uses WatchConnectivity framework (WatchManager/WatchStateModel)
- **Data Flow**: iPhone → Apple Watch (no direct sensor connections)
- **Libre 2 Support**: Exists via iOS app with NFC activation and transmitter bridges

### DiaBLE Reference Implementation
- **Direct BLE**: Apple Watch connects directly to sensors via CoreBluetooth
- **Service UUIDs**:
  - Libre 2/2+: `FDE3` (Abbott.dataServiceUUID)
  - Libre 3: `089810CC-EF89-11E9-81B4-2A2AE2DBCCE4`
- **Authentication**: Uses streaming unlock code and BLE PIN from NFC activation
- **Data Decryption**: Implements Libre2.decryptBLE() for 46-byte packets

## Implementation Plan

### Phase 1: Apple Watch BLE Infrastructure
1. **Create Watch BLE Manager** (`xDrip Watch App/Managers/WatchBluetoothManager.swift`)
   - Implement CBCentralManager for Apple Watch
   - Service discovery for Libre 2 Plus EU (UUID: FDE3)
   - Connection state management with single connection enforcement
   - Background extended runtime sessions
   - Mutex/coordination with iPhone to prevent dual connections

2. **Bluetooth Delegate** (`xDrip Watch App/Bluetooth/WatchBluetoothDelegate.swift`)
   - Peripheral discovery and filtering
   - Service/characteristic handling
   - Connection persistence
   - Auto-disconnect when iPhone is attempting connection

### Phase 2: Libre 2 Plus EU Protocol
1. **Port Libre 2 BLE Code** (`xDrip Watch App/CGM/Libre2Watch/`)
   - Create new watchOS-specific implementation (not sharing with iOS for simplicity)
   - Implement BLE packet handling (46 bytes: 20+18+8)
   - Remove all NFC dependencies

2. **Data Decryption** (`xDrip Watch App/CGM/Libre2Watch/Libre2Decryption.swift`)
   - Port `Libre2.decryptBLE()` from DiaBLE
   - Key generation using sensor UID and activation data
   - CRC validation
   - Implement decryption without external dependencies

3. **Glucose Data Processing**
   - Parse decrypted BLE data into glucose readings
   - Handle trend data (latest 7 sparse values)
   - Temperature compensation
   - Data quality checks

### Phase 3: Data Synchronization & Connection Management
1. **Activation Data Sharing**
   - Share sensor UID, patch info, and unlock code from iPhone via WatchConnectivity
   - Store in UserDefaults (Watch app container)
   - Clear data on sensor change
   - Single sensor support only

2. **Connection Arbitration**
   - iPhone has priority - Watch disconnects when iPhone wants to connect
   - Watch connects only when iPhone is disconnected/out of range
   - Use WatchConnectivity for coordination messages
   - Connection state machine:
     - IDLE → WAITING_FOR_IPHONE_DISCONNECT → CONNECTING → CONNECTED
     - CONNECTED → DISCONNECTING → IDLE (when iPhone requests)

3. **Local Storage**
   - Store last 24 hours of readings locally on Watch
   - Sync missing readings to iPhone when reconnected
   - No standalone operation - requires initial iPhone activation

### Phase 4: UI Integration
1. **Connection Status**
   - BLE connection state indicator
   - "iPhone Connected" vs "Watch Connected" status
   - Last reading timestamp
   - Signal strength (RSSI)

2. **Settings View**
   - Enable/disable direct Watch connection
   - Connection interval (1-5 minutes)
   - Debug view with raw BLE data
   - Force disconnect option

3. **Complications Update**
   - Direct updates from Watch BLE readings
   - Fallback to iPhone data when available
   - Update frequency based on power state

## Technical Implementation Details

### Background Execution
- Use `WKExtendedRuntimeSession` with `.healthTracking` type
- Request session before each reading interval
- Handle session expiration gracefully

### Battery Optimization
- Default 5-minute reading interval
- Disconnect between readings
- Reduce scanning time with known device address
- Disable when iPhone is connected

### Connection Management Protocol
```swift
// Message types between iPhone and Watch
enum ConnectionControlMessage {
    case iPhoneWantsToConnect
    case iPhoneDisconnected
    case watchRequestingConnection
    case watchConnected
    case watchDisconnected
}
```

### Minimum Requirements
- **watchOS**: Current version (watchOS 10+)
- **Note**: Evaluate watchOS 11 APIs for potential improvements before implementation

## Testing Process

### Phase 1: Development Testing
1. **Mock BLE Peripheral**
   - Create iPhone app that simulates Libre 2 BLE responses
   - Test connection/disconnection scenarios
   - Verify decryption with known test vectors

2. **Integration Testing**
   - TestFlight build with debug UI
   - Connection state logging
   - Raw BLE data display

### Phase 2: Real Sensor Testing
1. **Initial Activation**
   - Activate sensor with iPhone app
   - Verify activation data transfer to Watch
   - Test connection arbitration

2. **Continuous Testing Protocol**
   - Daily builds via TestFlight
   - Logging of all BLE interactions
   - Export logs feature for debugging
   - Specific test scenarios:
     - iPhone/Watch handoff
     - Out of range behavior
     - Background operation
     - Battery impact measurement

3. **Feedback Loop**
   - In-app feedback mechanism
   - Log bundle export
   - Connection statistics

## Error Handling

### Connection Failures
- Retry with exponential backoff
- Alert user after 3 failed attempts
- Fallback to iPhone data

### Decryption Errors
- Log raw packets for debugging
- Show "Sensor Error" to user
- Continue attempting connection

### State Conflicts
- iPhone always wins arbitration
- Watch gracefully disconnects
- Clear messaging to user

## Security Considerations
- Activation data stored in Watch app container only
- No keychain sharing (simpler implementation)
- BLE data is already encrypted by Libre 2 protocol
- No cloud sync of sensor credentials

## Success Metrics
- Connection reliability > 95%
- Reading interval accuracy ± 30 seconds
- Battery impact < 10% additional drain
- Handoff time < 10 seconds

## Future Enhancements (Out of Scope)
- Multiple sensor support
- Direct NFC activation from Watch
- Standalone operation without iPhone
- Historical data backfill
- Bridge device compatibility

## Next Steps
1. Set up watchOS development environment
2. Create connection management protocol
3. Implement BLE scanner proof of concept
4. Port decryption algorithms
5. Design TestFlight testing workflow