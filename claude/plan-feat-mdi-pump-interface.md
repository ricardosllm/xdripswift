# MDI "Virtual Pump" Interface for iAPS Integration

## Overview

The iAPS/OpenAPS algorithms are designed for pump-based insulin therapy and expect specific data structures and treatment types. For MDI (Multiple Daily Injection) users, we need to adapt the treatment data to match what the JavaScript algorithms expect.

## Key Differences: MDI vs Pump

### Pump-based therapy expects:
- Continuous basal insulin delivery (units/hour)
- Temporary basal rate adjustments
- Pump suspension/resume events
- Extended/combo boluses
- Specific event types: "Meal Bolus", "Correction Bolus", "Bolus Wizard"

### MDI therapy has:
- Long-acting basal insulin (once/twice daily)
- Rapid-acting bolus insulin (manual injections)
- No automated delivery or suspension
- Simple bolus entries

## Implementation Approach

### 1. Treatment Data Conversion

Transform xDripSwift's treatment types to match iAPS expectations:

```swift
// xDripSwift treatment types
case .Insulin  // Any insulin injection
case .Carbs    // Carbohydrate intake
case .Basal    // Long-acting insulin (not used in calculations)

// Convert to iAPS format
"eventType": "Meal Bolus"    // For insulin entries
"eventType": "Meal Bolus"    // For carb entries (with insulin=0)
"eventType": "Temp Basal"    // For MDI basal (if tracked)
```

### 2. Profile Adaptations

```javascript
// Required profile fields for iAPS
{
  "dia": 4.0,              // Duration of insulin action (hours)
  "carb_ratio": 15.0,      // Carbs per unit of insulin
  "sens": 50.0,            // Insulin sensitivity factor (mg/dL per unit)
  "curve": "rapid-acting", // Insulin action curve
  "current_basal": 0,      // Set to 0 for MDI
  "max_iob": 0,            // No pump basal to limit
  "basalprofile": []       // Empty for MDI
}
```

### 3. Missing Pump Features

For MDI users, certain pump features are not applicable:
- **Temp basals**: Not relevant for MDI
- **Pump suspensions**: Cannot suspend injections
- **Extended boluses**: All boluses are immediate
- **Basal IOB**: Only bolus insulin contributes to IOB

## Future Enhancements

### 1. MDI Notification Service
Create a "notification pump" that:
- Suggests insulin doses based on predictions
- Alerts user when action is needed
- Tracks manual injection confirmations
- Provides dosing history

### 2. Basal Insulin Tracking
For long-acting insulin:
- Track injection times and amounts
- Model basal insulin activity curve
- Include in background insulin calculations
- Warn about missed basal doses

### 3. Smart MDI Assistant
- Pre-meal bolus suggestions
- Correction dose calculations
- Stacking prevention alerts
- Exercise adjustments

## Implementation Status

✅ **Completed**:
- Basic treatment format conversion
- Profile adaptation for MDI
- IOB/COB calculation integration

⏳ **In Progress**:
- JavaScript execution debugging
- Prediction generation testing

🔲 **Future**:
- MDI notification service
- Basal insulin modeling
- Smart dosing assistant

## Testing Notes

When testing with MDI data:
1. Ensure insulin entries use "Meal Bolus" format
2. Carb entries should have insulin=0
3. Profile should have current_basal=0
4. Test with realistic DIA (4-6 hours for rapid-acting)
5. Verify IOB calculations match manual calculations