# MDI Loop Enhancement Plan: iAPS-Style Predictions and Display

## Current State Analysis

### xDripSwift Prediction System
- **Mathematical models**: Polynomial, logarithmic, exponential regression
- **IOB/COB calculations**: Linear models with simple absorption curves
- **Display**: Dotted line predictions with optional confidence bands
- **Missing**: Momentum, deviation, sensitivity adjustments, UAM detection

### iAPS/FreeAPS Approach (OpenAPS Algorithm)
- **Multiple prediction curves**: IOB-only, COB, UAM, zero-temp
- **Advanced features**: Momentum, deviation, autosens, dynamic ISF
- **Display**: Multiple colored prediction lines with clear legend

## Enhancement Plan

### Phase 1: Enhanced IOB/COB Display on Chart

#### 1.1 Add IOB/COB Values to Chart
- Display current IOB/COB values as text overlay on chart
- Position: Top-left corner with semi-transparent background
- Format: "IOB: 2.5U | COB: 35g"
- Update every minute with chart refresh

#### 1.2 Create IOB/COB Trend Lines
- Add secondary Y-axis for IOB/COB scale
- Display IOB curve as solid line (purple/blue)
- Display COB curve as solid line (orange/yellow)
- Show future IOB/COB decay based on current treatments

#### 1.3 Visual Treatment Markers
- Enhance existing treatment dots with:
  - Size proportional to dose/carbs
  - Insulin: Blue downward triangle
  - Carbs: Orange upward triangle
  - Show amount on hover/tap

### Phase 2: iAPS-Style Multiple Predictions

#### 2.1 Implement Multiple Prediction Scenarios
```swift
enum PredictionScenario {
    case iobOnly        // Only considers current IOB
    case cobAndIOB      // Considers both COB and IOB
    case uam            // Unannounced meal detection
    case zeroBasal      // What if basal was zero
    case exercise       // Exercise-adjusted (future)
}
```

#### 2.2 Enhanced Prediction Algorithm
```swift
struct EnhancedPredictionManager {
    // Key variables from iAPS/OpenAPS:
    - momentum: Rate of change acceleration
    - deviation: Actual vs expected BG
    - sensitivity: Dynamic ISF based on patterns
    - carbAbsorptionRate: Dynamic based on time of day
    - insulinPeakTime: Varies by insulin type
    - basalRate: Current basal (for MDI: average daily basal)
}
```

#### 2.3 Momentum Calculation
```swift
func calculateMomentum(readings: [BgReading]) -> Double {
    // Average rate of change over last 15 minutes
    let recentTrend = calculateTrend(last: 3)
    // Average rate of change over last 30 minutes
    let longerTrend = calculateTrend(last: 6)
    // Momentum = acceleration of glucose change
    return recentTrend - longerTrend
}
```

#### 2.4 Deviation Calculation
```swift
func calculateDeviation(actual: Double, expected: Double) -> Double {
    // Deviation = how far off predictions were
    // Used to detect unannounced meals or incorrect settings
    return actual - expected
}
```

### Phase 3: Chart Display Enhancements

#### 3.1 Multiple Prediction Lines
```swift
struct PredictionDisplay {
    let iobOnlyLine: ChartLineLayer     // Purple dotted
    let cobLine: ChartLineLayer         // Orange dotted
    let uamLine: ChartLineLayer         // Yellow dotted
    let eventualLine: ChartPoint        // Final predicted value marker
}
```

#### 3.2 Chart Legend
- Add toggleable legend showing:
  - Current BG with trend arrow
  - IOB with units
  - COB with grams
  - Predicted values for each scenario
  - Time to target range

#### 3.3 Enhanced Visual Indicators
- Shaded areas for target range
- Gradient fill under glucose line
- Animated transitions for predictions
- Touch interaction to show values

### Phase 4: MDI-Specific Enhancements

#### 4.1 MDI Bolus Calculator Integration
```swift
struct MDIRecommendationEnhanced {
    // Base recommendation
    let correctionDose: Double
    let mealDose: Double
    
    // Scenario-based adjustments
    let iobAdjustment: Double
    let momentumAdjustment: Double
    let deviationAdjustment: Double
    
    // Final recommendation with explanation
    let finalDose: Double
    let reasoning: [String]  // Step-by-step calculation
    
    // Visual prediction impact
    let predictedGlucoseCurve: [ChartPoint]
    let timeToTarget: TimeInterval
}
```

#### 4.2 Smart Notification Content
- Include mini prediction graph in notification
- Show IOB/COB values
- Display multiple scenarios
- Quick actions for different dose options

#### 4.3 MDI-Specific Variables
```swift
struct MDILoopSettings {
    // MDI users don't have basal adjustments
    let averageDailyBasal: Double  // For calculations
    let typicalBolusTimings: [Date] // Meal patterns
    let exerciseSchedule: [ExerciseBlock] // Regular activities
    let insulinStackingLimit: Double // Safety threshold
}
```

### Phase 5: Implementation Steps

#### 5.1 Core Algorithm Updates
1. Enhance IOBCalculator with insulin activity curves
2. Improve COBCalculator with dynamic absorption
3. Add momentum and deviation tracking
4. Implement UAM detection algorithm

#### 5.2 Chart Updates
1. Modify GlucoseChartManager to support multiple lines
2. Add IOB/COB overlay components
3. Implement interactive legend
4. Create notification content extension

#### 5.3 MDI Loop Integration
1. Update MDILoopManager with enhanced predictions
2. Modify MDIBolusCalculator to use all variables
3. Enhance notifications with prediction graphs
4. Add recommendation history tracking

### Key Variables for Complete Prediction

From iAPS/OpenAPS algorithm:

```swift
struct PredictionVariables {
    // Glucose Data
    let currentBG: Double
    let bgReadings: [BgReading]  // Last 4 hours
    
    // Insulin Variables
    let iob: Double              // Current IOB
    let iobArray: [IOBValue]     // Future IOB curve
    let basalRate: Double        // For MDI: estimated daily basal
    let isf: Double              // Insulin sensitivity
    let dia: Double              // Duration of insulin action
    let insulinPeak: Double      // Peak activity time
    
    // Carb Variables
    let cob: Double              // Current COB
    let cobArray: [COBValue]     // Future COB curve
    let carbRatio: Double        // I:C ratio
    let carbAbsorptionRate: Double // g/hour
    let carbAbsorptionDelay: Double // minutes
    
    // Advanced Variables
    let momentum: Double         // BG acceleration
    let deviation: Double        // Actual vs expected
    let sensitivity: Double      // Dynamic ISF multiplier
    let autosens: Double        // Auto-sensitivity ratio
    
    // MDI Specific
    let lastBolusTime: Date     // For stacking prevention
    let dailyBasalEstimate: Double // Total daily basal
    let mealPattern: MealPattern // Typical eating times
}
```

### Visual Mockup

```
┌─────────────────────────────────────┐
│ IOB: 2.5U ↓  COB: 35g ↑   [Legend] │
├─────────────────────────────────────┤
│ 400 ┼─────────────────────────────┤ │
│     │                              │ │
│ 300 ┼─────────────────────────────┤ │
│     │         ╱╲    ···········    │ │
│ 200 ┼────────╱──╲··┅┅┅┅┅┅┅┅┅┅┅───┤ │
│     │       ╱    ╲·┅┅┅┅┅┅┅┅┅      │ │
│ 100 ┼──────╱──────┅┅┅┅┅┅┅─────────┤ │
│     │     ╱                        │ │
│   0 └─────┴────┴────┴────┴────┴───┘ │
│     Now  +30m  +1h  +1.5h  +2h     │
│                                     │
│ ── BG  ··· IOB only  ┅┅┅ COB+IOB  │
│ △ Bolus  ▽ Carbs                    │
└─────────────────────────────────────┘
```

## Benefits for MDI Users

1. **Better Understanding**: See exactly how IOB/COB affect future glucose
2. **Improved Decisions**: Multiple scenarios help choose best action
3. **Safety**: Momentum detection prevents over-correction
4. **Learning**: Visual feedback improves understanding of insulin/carb timing
5. **Confidence**: Evidence-based recommendations with clear reasoning

## Next Steps

1. Implement enhanced IOB/COB display (Phase 1)
2. Add momentum/deviation calculations (Phase 2.2-2.4)
3. Create multiple prediction scenarios (Phase 2.1)
4. Update chart with multiple lines (Phase 3)
5. Integrate with MDI notifications (Phase 4)

This approach brings the sophisticated prediction capabilities of iAPS/OpenAPS to MDI users while maintaining the simplicity and safety appropriate for manual insulin delivery.