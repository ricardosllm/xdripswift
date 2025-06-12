# Watch Notification Snooze Bug Plan

## Bug: Watch Notification Snooze Action Not Working

### Problem Description

When receiving high or low glucose alerts on Apple Watch, tapping the "Snooze" action on the notification does not actually snooze the alert. The alert continues to fire repeatedly despite the user attempting to snooze it from their watch.

### Current Behavior

1. User receives glucose alert notification on Apple Watch
2. User taps "Snooze" action on the notification
3. No visual feedback that snooze was processed
4. Alert continues to fire at regular intervals
5. iPhone app shows no indication that snooze was attempted

### Expected Behavior

1. User receives glucose alert notification on Apple Watch
2. User taps "Snooze" action on the notification
3. Watch provides feedback that snooze was accepted
4. Alert is snoozed for the configured duration
5. iPhone app reflects the snoozed state

### Root Cause Analysis

The watch notification snooze action fails because there's no communication channel between the watch notification action and the iPhone app's AlertManager:

1. **Missing Watch → iPhone Communication**: When a snooze action is tapped on the watch, no message is sent to the iPhone
2. **No Action Handler**: The watch app doesn't implement handling for notification actions
3. **Disconnected Systems**: Watch notifications are handled locally without forwarding actions to the companion app

### Technical Details

#### Current Implementation Flow
```
iPhone AlertManager → Creates Notification → Delivered to Watch → User Taps Snooze → ❌ Nothing Happens
```

#### Required Implementation Flow
```
iPhone AlertManager → Creates Notification → Delivered to Watch → User Taps Snooze → Watch Sends Message → iPhone Processes Snooze
```

### Files Requiring Changes

#### Watch Side
- `xDrip Watch App/DataModels/NotificationController.swift` - Add snooze action handling
- `xDrip Watch App/DataModels/WatchStateModel.swift` - Add message sending for snooze
- `xDrip Watch App/xDripWatchApp.swift` - Ensure proper notification delegate setup

#### iPhone Side
- `xdrip/Managers/Watch/WatchManager.swift` - Add message reception for snooze requests
- `xdrip/Managers/Alerts/AlertManager.swift` - Expose snooze method for watch requests

## Implementation Plan

### Phase 1: Watch Notification Action Handling (Day 1)

**1.1 Implement UNUserNotificationCenterDelegate on Watch**

```swift
// In xDripWatchApp.swift or NotificationController.swift
extension NotificationController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if response.actionIdentifier == "snoozeActionIdentifier" {
            // Extract alert info from notification
            let userInfo = response.notification.request.content.userInfo
            
            // Send snooze request to iPhone
            WatchStateModel.shared.sendSnoozeRequest(alertKind: userInfo["alertKind"] as? String)
        }
        
        completionHandler()
    }
}
```

**1.2 Add Snooze Message Sending in WatchStateModel**

```swift
// In WatchStateModel.swift
func sendSnoozeRequest(alertKind: String?) {
    guard wcSession.isReachable else {
        // Store for later sending when connection is available
        pendingSnoozeRequest = alertKind
        return
    }
    
    let message = [
        "messageType": "snoozeAlert",
        "alertKind": alertKind ?? "unknown",
        "timestamp": Date().timeIntervalSince1970
    ]
    
    wcSession.sendMessage(message, replyHandler: { reply in
        // Handle success response
        print("Snooze confirmed: \(reply)")
    }, errorHandler: { error in
        // Handle error
        print("Snooze failed: \(error)")
    })
}
```

### Phase 2: iPhone Message Reception (Day 1-2)

**2.1 Add Message Handling in WatchManager**

```swift
// In WatchManager.swift
func session(_ session: WCSession, didReceiveMessage message: [String : Any], 
             replyHandler: @escaping ([String : Any]) -> Void) {
    
    if let messageType = message["messageType"] as? String, 
       messageType == "snoozeAlert" {
        
        let alertKind = message["alertKind"] as? String ?? "unknown"
        
        // Process snooze request
        DispatchQueue.main.async {
            let success = self.processSnoozeRequest(alertKind: alertKind)
            replyHandler(["success": success, "message": "Snooze processed"])
        }
    }
}

private func processSnoozeRequest(alertKind: String) -> Bool {
    // Determine alert type and call appropriate snooze method
    switch alertKind {
    case "high":
        return AlertManager.shared.snoozeHighAlert()
    case "low":
        return AlertManager.shared.snoozeLowAlert()
    default:
        // Try to snooze any active alert
        return AlertManager.shared.snoozeActiveAlert()
    }
}
```

**2.2 Expose Snooze Methods in AlertManager**

```swift
// In AlertManager.swift
public func snoozeHighAlert() -> Bool {
    // Implementation to snooze high alert
    // Return success status
}

public func snoozeLowAlert() -> Bool {
    // Implementation to snooze low alert
    // Return success status
}

public func snoozeActiveAlert() -> Bool {
    // Snooze any currently active alert
    // Return success status
}
```

### Phase 3: Notification Content Enhancement (Day 2)

**3.1 Add Alert Type to Notification UserInfo**

```swift
// In AlertManager.swift - when creating notification content
content.userInfo = [
    "alertKind": alertKind.rawValue,
    "bgValueInMgDl": bgReading.calculatedValue,
    "bgValueTimestamp": bgReading.timeStamp.timeIntervalSince1970
]
```

### Phase 4: User Feedback (Day 2)

**4.1 Provide Visual Feedback on Watch**

```swift
// In NotificationController after sending snooze
WKInterfaceDevice.current().play(.success)

// Show confirmation in notification view
DispatchQueue.main.async {
    self.statusLabel.setText("Snoozed ✓")
    self.statusLabel.setTextColor(.green)
}
```

### Phase 5: Error Handling & Edge Cases (Day 3)

**5.1 Handle Offline Scenarios**
- Queue snooze requests when watch is not connected
- Send queued requests when connection is restored
- Add timeout handling for message sending

**5.2 Handle Multiple Alert Types**
- Properly identify which alert type to snooze
- Handle case where multiple alerts are active
- Ensure correct alert is snoozed

### Testing Plan

1. **Unit Tests**
   - Test message serialization/deserialization
   - Test alert type identification
   - Test offline queueing mechanism

2. **Integration Tests**
   - Test end-to-end snooze flow
   - Test with various alert types
   - Test offline/online transitions

3. **Manual Testing Scenarios**
   - Test snooze with watch app in foreground
   - Test snooze with watch app in background
   - Test snooze with iPhone app closed
   - Test snooze with poor connectivity
   - Test rapid multiple snooze attempts

### Success Criteria

1. Snooze action on watch successfully snoozes the alert 95%+ of the time
2. User receives visual/haptic feedback within 1 second
3. Alert stops firing for the configured snooze duration
4. iPhone app reflects snoozed state correctly
5. Works reliably even with intermittent connectivity

### Risk Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| WatchConnectivity unreliable | High | Implement retry logic and offline queue |
| Message timing issues | Medium | Add timestamp validation and timeout handling |
| Multiple simultaneous alerts | Medium | Implement alert priority system |
| Battery impact | Low | Use efficient message batching |

### Timeline

- **Day 1**: Implement watch-side action handling and message sending
- **Day 2**: Implement iPhone-side message reception and processing
- **Day 3**: Add error handling, testing, and polish
- **Total**: 3 days development + 1 day testing

### Follow-up Improvements

1. Add snooze duration customization from watch
2. Show remaining snooze time on watch complication
3. Add force touch menu for quick snooze options
4. Implement smart snooze based on glucose trend