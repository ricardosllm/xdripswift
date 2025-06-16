# MDI Loop Emulation: Notification-Based Bolus Recommendations

## Overview

This document outlines the implementation of a loop emulation system for MDI (Multiple Daily Injections) users in xdripswift. The core concept is translating automated pump commands into actionable notifications that guide MDI users to manually inject the recommended insulin doses.

## Key Concept: Loop → Notification Translation

Traditional Loop System:
```
Algorithm → Calculate Bolus → Send Command to Pump → Insulin Delivered
```

MDI Loop Emulation:
```
Algorithm → Calculate Bolus → Generate Notification → User Manually Injects → Log Injection
```

## Core Components

### 1. MDI Loop Manager

```swift
class MDILoopManager {
    // Core loop emulation logic
    private let predictionManager: PredictionManager
    private let bolusCalculator: MDIBolusCalculator
    private let notificationManager: MDINotificationManager
    private let safetyChecker: MDISafetyChecker
    
    // Loop cycle (runs every 5 minutes)
    func runLoopCycle() {
        // 1. Get current glucose data
        // 2. Run predictions
        // 3. Calculate recommended actions
        // 4. Apply safety checks
        // 5. Generate notifications if needed
    }
}
```

### 2. Intelligent Notification System

#### Notification Types

1. **Correction Bolus Alert**
   - Triggered when BG is high and trending up
   - Includes recommended units
   - Shows prediction curve if user acts

2. **Pre-meal Reminder**
   - Based on historical meal patterns
   - Suggests pre-bolus timing
   - Shows optimal injection-to-meal delay

3. **Micro-bolus Suggestions**
   - Small corrections throughout the day
   - Emulates pump micro-bolusing
   - Aggregates small doses into practical amounts

4. **Basal Adjustment Alert**
   - For split basal users
   - Suggests timing/dose adjustments
   - Based on overnight patterns

#### Notification Content Structure

```swift
struct MDIBolusNotification {
    let id: UUID
    let timestamp: Date
    let type: NotificationType
    let recommendedDose: Double
    let reason: String
    let urgency: UrgencyLevel
    let predictions: [PredictionPoint]
    let expiresAt: Date
    let safetyInfo: SafetyInfo
}

enum NotificationType {
    case correctionBolus
    case mealBolus
    case microBolus
    case basalAdjustment
    case urgentCorrection
}

enum UrgencyLevel {
    case low      // Can wait 30+ minutes
    case medium   // Within 15-30 minutes
    case high     // Within 15 minutes
    case critical // Immediately
}
```

### 3. Safety Framework

#### Dose Validation
```swift
struct MDISafetyChecker {
    func validateRecommendation(_ dose: Double, context: DosingContext) -> SafetyResult {
        // Check against:
        // - Maximum single dose limits
        // - Daily total limits
        // - Recent injection history
        // - Active IOB
        // - Rate of change constraints
        // - Time since last dose
    }
}

struct SafetyResult {
    let isApproved: Bool
    let adjustedDose: Double?
    let warnings: [String]
    let restrictions: [SafetyRestriction]
}
```

#### User Confirmation Requirements
- All recommendations require explicit user action
- Critical doses show additional confirmation
- Includes "snooze" option for non-urgent alerts
- Tracks ignored recommendations for learning

### 4. Advanced Features

#### A. Dose Stacking Prevention
```swift
class DoseStackingPrevention {
    // Prevents overlapping dose recommendations
    func checkRecentNotifications() -> Bool
    func mergeRecommendations() -> MDIBolusNotification
    func calculateMinimumInterval() -> TimeInterval
}
```

#### B. Learning System
```swift
class MDIUserPatternLearning {
    // Learns from user behavior
    func recordUserResponse(notification: MDIBolusNotification, action: UserAction)
    func adjustFutureRecommendations()
    func identifyOptimalNotificationTimes()
}
```

#### C. Meal Detection Integration
```swift
class MealDetectionForMDI {
    // Detects unannounced meals
    func detectMealStart() -> MealDetectionResult
    func suggestRetrospectiveBolus()
    func calculateCatchUpDose()
}
```

## Implementation Architecture

### Notification Flow

1. **Loop Cycle Trigger** (every 5 minutes)
   ```swift
   Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
       mdiLoopManager.runLoopCycle()
   }
   ```

2. **Decision Engine**
   ```swift
   func shouldGenerateNotification() -> NotificationDecision {
       // Check glucose levels, trends, predictions
       // Consider recent notifications
       // Apply user preferences
       // Respect quiet hours
   }
   ```

3. **Notification Generation**
   ```swift
   func generateNotification() -> UNNotificationRequest {
       // Create rich notification with:
       // - Clear dose recommendation
       // - Visual prediction graph
       // - Quick actions (Accept/Snooze/Modify)
       // - Safety information
   }
   ```

4. **User Response Handling**
   ```swift
   func handleNotificationResponse(_ response: UNNotificationResponse) {
       switch response.actionIdentifier {
       case "accept":
           logPlannedInjection()
           scheduleFollowUp()
       case "modify":
           presentDoseAdjustmentUI()
       case "snooze":
           scheduleReminderNotification()
       }
   }
   ```

### UI Components

#### 1. MDI Loop Status View
```swift
// Shows current loop status
- Active/Inactive state
- Last recommendation
- Next check time
- Quick enable/disable
```

#### 2. Notification History
```swift
// Tracks all recommendations
- Accepted/Ignored/Modified
- Actual outcomes
- Learning insights
```

#### 3. Settings Panel
```swift
// MDI-specific loop settings
- Notification preferences
- Dose limits
- Quiet hours
- Aggressiveness settings
```

## Safety Considerations

### 1. Notification Fatigue Prevention
- Intelligent clustering of recommendations
- Respect minimum intervals between alerts
- User-configurable quiet periods
- Smart snoozing with context

### 2. Clear Disclaimers
```swift
struct MDILoopDisclaimer {
    static let primary = """
    This is a recommendation system only. 
    All insulin doses must be manually 
    administered. Always verify recommendations 
    with your current glucose levels.
    """
}
```

### 3. Emergency Overrides
- "Pause all recommendations" button
- Sick day mode adjustments
- Exercise mode modifications
- Travel/timezone handling

### 4. Dose Limits
```swift
struct MDIDoseLimits {
    let maxSingleCorrection: Double = 5.0
    let maxHourlyTotal: Double = 10.0
    let maxDailyTotal: Double = 100.0
    let minTimeBetweenDoses: TimeInterval = 1800 // 30 minutes
}
```

## Technical Implementation

### 1. Notification Permissions
```swift
// Request critical alert permissions
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge, .criticalAlert]
)
```

### 2. Rich Notifications
```swift
// Use notification content extension
class MDINotificationViewController: UIViewController, UNNotificationContentExtension {
    // Show glucose graph
    // Display dose calculation
    // Provide quick actions
}
```

### 3. Background Processing
```swift
// Background task for loop cycles
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.xdrip.mdi-loop",
    using: nil
) { task in
    mdiLoopManager.runBackgroundCycle()
}
```

### 4. Data Persistence
```swift
// Core Data extensions
extension MDILoopRecommendation: NSManagedObject {
    // Store all recommendations
    // Track user responses
    // Maintain audit trail
}
```

## User Experience Flow

### Initial Setup
1. Enable MDI Loop in settings
2. Configure personal limits
3. Set notification preferences
4. Complete safety quiz
5. Start with conservative settings

### Daily Use
1. Receive notification
2. Check current BG
3. Review recommendation
4. Inject if appropriate
5. Log injection in app

### Feedback Loop
1. App tracks outcomes
2. Adjusts future recommendations
3. Shows effectiveness reports
4. Suggests setting changes

## Integration Points

### With Existing Features
- Uses existing prediction engine
- Leverages IOB calculations
- Integrates with meal logging
- Shares data with reports

### With Future Features
- Smart pen integration
- Voice assistant support
- Apple Watch complications
- Widget quick actions

## Development Phases

### Phase 1: Basic Notifications
- Simple correction bolus alerts
- Manual dose logging
- Basic safety checks

### Phase 2: Intelligent Timing
- Meal pattern recognition
- Optimal notification timing
- Dose stacking prevention

### Phase 3: Advanced Loop Features
- Micro-bolus aggregation
- Basal adjustment suggestions
- Learning algorithms

### Phase 4: Rich Interactions
- Notification extensions
- Quick dose modifications
- Visual predictions

## Success Metrics

1. **Safety Metrics**
   - Zero unsafe recommendations
   - Proper dose limit adherence
   - No notification storms

2. **Effectiveness Metrics**
   - Improved time in range
   - Reduced glucose variability
   - User satisfaction scores

3. **Usability Metrics**
   - Notification response rate
   - Feature engagement
   - Setting optimization

## Conclusion

This MDI Loop Emulation system bridges the gap between automated insulin delivery and manual injection therapy. By providing timely, intelligent, and safe recommendations through a familiar notification interface, we can help MDI users achieve better glucose control while maintaining full control over their insulin delivery.