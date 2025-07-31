# Libre 2 Connection Analysis & Improvement Plan

## Current Issues

### 1. iPhone Disconnection
- **Problem**: iPhone might not be fully disconnecting from sensor
- **Impact**: Sensor won't advertise if still connected to iPhone
- **Solution**: Verify disconnection and add delay before Watch scan

### 2. BLE Discovery Limitations
- **Problem**: Libre 2 sensors often:
  - Don't advertise their name (show as "Unknown")
  - Don't advertise service UUID (FDE3)
  - Have weak/variable RSSI
- **Impact**: Watch can't identify sensor in scan
- **Solution**: More aggressive connection strategy

### 3. Time Window Management
- **Problem**: Only 5 minutes after NFC activation
- **Impact**: Every second counts
- **Solution**: Optimize entire flow for speed

## Proposed Improvements

### 1. Enhanced iPhone Disconnection
```swift
// BluetoothPeripheralManager.swift
func scanForLibre2ForWatchHandover() {
    // 1. Force disconnect with verification
    transmitter.disconnect()
    transmitter.peripheral = nil  // Clear reference
    
    // 2. Wait for disconnection confirmation
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        // 3. Verify disconnection
        if transmitter.isConnected() {
            // Force disconnect again
            transmitter.forceDisconnect()
        }
        
        // 4. Start NFC scan
        startNFCScan()
    }
}
```

### 2. Aggressive Watch Discovery
```swift
// WatchBluetoothManager.swift
private func performScan() {
    // Strategy: Connect to EVERYTHING and check later
    
    // 1. Scan without any filters
    centralManager?.scanForPeripherals(
        withServices: nil,  // No service filter
        options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
            CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [libre2ServiceUUID]
        ]
    )
    
    // 2. Connect to all potential devices immediately
    // - Any unnamed device
    // - Any device with ABBOTT in name
    // - Any device with serial in name
    // - Any device with reasonable RSSI
}

func didDiscover(peripheral: CBPeripheral) {
    // Connect first, ask questions later
    if isPotentialLibre2(peripheral) {
        connectImmediately(peripheral)
    }
}

private func isPotentialLibre2(_ peripheral: CBPeripheral) -> Bool {
    // Very permissive criteria
    return peripheral.name == nil ||
           peripheral.name == "Unknown" ||
           peripheral.name?.contains("ABBOTT") == true ||
           peripheral.name?.contains(targetSerial) == true ||
           RSSI > -90  // Very weak signal OK
}
```

### 3. Parallel Connection Attempts
```swift
// Try multiple devices simultaneously
class ParallelConnectionManager {
    var activeConnections: [CBPeripheral] = []
    let maxParallel = 3
    
    func tryDevice(_ peripheral: CBPeripheral) {
        if activeConnections.count < maxParallel {
            activeConnections.append(peripheral)
            connect(peripheral)
        }
    }
    
    func didConnect(_ peripheral: CBPeripheral) {
        // Check if Libre 2
        peripheral.discoverServices([libre2ServiceUUID])
    }
    
    func didDiscoverServices(_ peripheral: CBPeripheral) {
        if hasLibre2Service(peripheral) {
            // Success! Cancel others
            cancelOtherConnections(except: peripheral)
        } else {
            // Not Libre 2, try next
            disconnect(peripheral)
            tryNextInQueue()
        }
    }
}
```

### 4. Time-Aware Connection Strategy
```swift
class TimeWindowManager {
    let nfcActivationTime: Date
    let windowDuration: TimeInterval = 300 // 5 minutes
    
    var remainingTime: TimeInterval {
        return windowDuration - Date().timeIntervalSince(nfcActivationTime)
    }
    
    var urgencyLevel: UrgencyLevel {
        switch remainingTime {
        case 240...: return .low      // 4-5 min: Normal
        case 120..<240: return .medium // 2-4 min: Faster
        case 60..<120: return .high    // 1-2 min: Aggressive
        case 0..<60: return .critical  // <1 min: Connect anything!
        default: return .expired
        }
    }
    
    func connectionStrategy() -> ConnectionStrategy {
        switch urgencyLevel {
        case .low:
            return .selective // Check name/service
        case .medium:
            return .permissive // Connect unnamed devices
        case .high:
            return .aggressive // Connect all devices
        case .critical:
            return .desperate // No filtering at all
        case .expired:
            return .stop
        }
    }
}
```

### 5. Connection State Machine
```swift
enum ConnectionState {
    case idle
    case waitingForIPhoneDisconnect
    case nfcScanning
    case bleActivated(expiry: Date)
    case scanning(strategy: ConnectionStrategy)
    case connecting(devices: [CBPeripheral])
    case verifying(peripheral: CBPeripheral)
    case connected
    case failed(reason: String)
}

class ConnectionStateMachine {
    var state: ConnectionState = .idle
    let timeWindow = TimeWindowManager()
    
    func transition(to newState: ConnectionState) {
        // Log state transitions
        logger.info("State: \(state) -> \(newState)")
        
        // Update UI
        updateUI(for: newState)
        
        // Take action based on new state
        switch newState {
        case .bleActivated(let expiry):
            timeWindow.start(expiry: expiry)
            transition(to: .scanning(strategy: .selective))
            
        case .scanning(let strategy):
            if timeWindow.urgencyLevel == .expired {
                transition(to: .failed(reason: "BLE window expired"))
            } else {
                startScanning(with: strategy)
            }
            
        // ... handle other states
        }
    }
}
```

## Implementation Priority

1. **Immediate**: Fix iPhone disconnection verification
2. **High**: Implement aggressive Watch scanning
3. **Medium**: Add parallel connection attempts
4. **Low**: Implement full state machine

## Quick Wins

1. Remove RSSI filtering entirely
2. Connect to all unnamed devices
3. Increase scan timeout to 45 seconds
4. Start Watch scan immediately after NFC (don't wait for iPhone confirmation)
5. Pre-warm Watch Bluetooth before NFC scan

## Testing Strategy

1. Log all BLE advertisements to file
2. Measure time from NFC scan to connection
3. Test with sensor at various distances
4. Test with other BLE devices nearby
5. Test connection recovery after timeout