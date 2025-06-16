# MDI Loop Feature - User Testing Guide

## What to Test as an End User

### 1. **Enable the Feature**
- Go to **Settings** → **MDI Loop Settings**
- Toggle **"MDI Loop Enabled"** to ON
- Toggle **"Enable Notifications"** to ON
- Set your notification preferences

### 2. **What Happens Next**
Once enabled, the MDI Loop runs silently in the background, checking your glucose every 5 minutes. You won't see anything in the UI until...

### 3. **When You'll Get Notifications**

You'll receive notifications in these scenarios:

#### **Urgent Low (< 55 mg/dL)**
- **Notification**: "🍬 Carbs Needed"
- **Message**: "Glucose is urgently low at 45 mg/dL"
- **Recommendation**: "Recommended: 15g carbs"
- **Actions**: [Log Injection] [Snooze 15 min] [Dismiss]

#### **Urgent High (> 250 mg/dL)**
- **Notification**: "💉 Correction Recommended"
- **Message**: "Glucose is urgently high at 280 mg/dL"
- **Recommendation**: "Recommended: 2.5 units"
- **Actions**: [Log Injection] [Snooze 15 min] [Dismiss]

#### **High with Rising Trend (> 180 mg/dL and rising)**
- **Notification**: "💉 Correction Recommended"
- **Message**: "Glucose is high and rising"
- **Recommendation**: "Recommended: 1.5 units"
- Only if you set notification threshold to "High + Urgent" or "Any"

#### **Low with Falling Trend (< 80 mg/dL and falling)**
- **Notification**: "🍬 Carbs Needed"
- **Message**: "Glucose is low and falling"
- **Recommendation**: "Recommended: 10g carbs"
- Only if you set notification threshold to "High + Urgent" or "Any"

### 4. **Testing the Feature**

To test without waiting for actual high/low glucose:

1. **Check if it's running**: 
   - After enabling, you should see in device logs: "MDI Loop started"
   - Every 5 minutes: "Running MDI loop cycle"

2. **Test notifications**:
   - The easiest way to test is to wait for your glucose to cross a threshold
   - Or temporarily adjust your thresholds in Settings to trigger notifications

3. **Notification Actions**:
   - **"Log Injection"** - Currently just dismisses (future: will log treatment)
   - **"Snooze 15 min"** - Silences similar notifications for 15 minutes
   - **"Dismiss"** - Dismisses this notification

### 5. **What You WON'T See**

- No UI changes in the main screen
- No new buttons or indicators
- No charts or graphs (yet)
- No treatment logging (yet)
- No history view (yet)

### 6. **Important Settings to Check**

In **MDI Loop Settings**:
- **Notification Urgency**: 
  - "Urgent only" = Only critical highs/lows
  - "High + Urgent" = Includes non-critical highs/lows
  - "Any" = All recommendations (future)
- **Notification Sound**: ON for audible alerts
- **Show Prediction Impact**: Currently placeholder
- **Pre-Meal Reminders**: Currently placeholder

### 7. **Verify It's Working**

You'll know it's working when:
1. Settings show MDI Loop is enabled
2. You get notifications when glucose crosses thresholds
3. The notifications have MDI-specific actions (not regular xDrip alerts)
4. Notifications respect your snooze choices

### 8. **Current Limitations**

- Dose calculations are basic (glucose - target) / ISF
- No IOB/COB considerations yet (calculator is ready but not integrated)
- No visual indicators in the app
- No recommendation history
- No meal bolus suggestions yet

The feature is designed to be **non-intrusive** - it won't change your existing xDrip experience, it just adds smart notifications when you need to take action with your MDI therapy.

## Technical Notes

### Files Added:
- `xdrip/Managers/MDI/MDILoopManagerProtocol.swift` - Protocol definitions
- `xdrip/Managers/MDI/MDILoopManager.swift` - Main loop implementation
- `xdrip/Managers/MDI/MDINotificationManager.swift` - Notification handling
- `xdrip/Managers/MDI/MDIBolusCalculator.swift` - Advanced dose calculations (not yet integrated)
- `xdrip/View Controllers/SettingsNavigationController/SettingsViewController/SettingsViewModels/SettingsViewMDILoopSettingsViewModel.swift` - Settings UI

### Files Modified:
- `xdrip/Extensions/UserDefaults.swift` - Added MDI-specific settings
- `xdrip/View Controllers/Root View Controller/RootViewController.swift` - MDI Loop integration
- `xdrip/Texts/TextsSettingsView.swift` - UI text strings
- `xdrip/View Controllers/SettingsNavigationController/SettingsViewController/SettingsViewUtilities.swift` - Added MDI section

### Next Steps:
1. Add MDIBolusCalculator to Xcode project
2. Implement actual IOB/COB calculations
3. Create notification content extension for rich notifications
4. Add treatment logging when user accepts recommendation
5. Create recommendation history view