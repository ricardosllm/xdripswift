# Enhanced Glucose Graph with Prediction Emphasis and Action Recommendations

## Overview

This document outlines enhancements to the main glucose graph in xdripswift to provide better visual emphasis on predictions and actionable recommendations for improving glucose control over time.

## Design Goals

1. **Make predictions prominent** - Users should immediately see where their glucose is heading
2. **Provide clear actions** - Graph should suggest what to do, not just show data
3. **Show impact** - Visualize how recommended actions would affect glucose trajectory
4. **Historical context** - Learn from patterns to provide better recommendations

## Visual Design Enhancements

### 1. Prediction Visualization

#### A. Multi-Scenario Predictions
```swift
struct PredictionScenarios {
    let baseline: [PredictionPoint]      // No action taken
    let withRecommended: [PredictionPoint] // If recommendation followed
    let withMeal: [PredictionPoint]      // If meal detected/planned
    let withExercise: [PredictionPoint]  // If exercise detected/planned
}
```

**Visual Implementation:**
- **Baseline**: Solid line with gradient fade
- **With Action**: Dashed line showing improved trajectory
- **Confidence bands**: Shaded area showing uncertainty
- **Key points**: Dots at critical moments (predicted high/low)

#### B. Prediction Emphasis Techniques
1. **Gradient Intensity**: Darker colors for near-term, fading for distant
2. **Line Weight**: Thicker for high-confidence predictions
3. **Animation**: Subtle pulse on prediction line to draw attention
4. **Color Coding**: 
   - Green: In range predictions
   - Yellow: Approaching limits
   - Red: Out of range predictions

### 2. Action Recommendation Overlays

#### A. Action Indicators
```swift
struct ActionIndicator {
    let timestamp: Date
    let type: ActionType
    let urgency: UrgencyLevel
    let impact: GlucoseImpact
    let confidence: Double
}

enum ActionType {
    case correctionBolus(units: Double)
    case carbsNeeded(grams: Int)
    case preemptiveBolus(units: Double)
    case activityAdjustment
    case basalAdjustment
}
```

**Visual Markers:**
- **Injection icons**: 💉 with dose amount
- **Carb icons**: 🍎 with gram amount
- **Activity icons**: 🏃 for exercise adjustments
- **Warning icons**: ⚠️ for urgent actions

#### B. Action Cards
Floating cards that appear when tapping prediction points:
```swift
struct ActionCard {
    // Header
    let title: String // "Recommended Action"
    let urgency: UrgencyBadge
    
    // Content
    let primaryAction: String // "Take 2.5 units"
    let reason: String // "To prevent high in 45 min"
    let confidence: ConfidenceIndicator // 85% sure
    
    // Visualization
    let impactPreview: MiniGraph // Shows before/after
    
    // Actions
    let acceptButton: Button
    let modifyButton: Button
    let dismissButton: Button
}
```

### 3. Smart Annotations

#### A. Contextual Information
```swift
class SmartAnnotations {
    func annotateGraph(at point: ChartPoint) -> Annotation? {
        // Meal markers with carb counts
        // Insulin markers with IOB decay
        // Exercise markers with impact duration
        // Pattern recognition callouts
    }
}
```

#### B. Trend Insights
Automatic insights that appear above the graph:
- "Rising quickly - consider correction"
- "Steady in range - great control!"
- "Pattern detected: Post-lunch spike"
- "Overnight basal may need adjustment"

## Interactive Features

### 1. Gesture Controls

#### A. Swipe Predictions
- **Swipe right**: Show what happens with no action
- **Swipe left**: Show impact of recommended action
- **Pinch**: Zoom in/out on prediction timeline

#### B. Touch Interactions
- **Tap prediction**: Show action card
- **Long press**: Compare multiple scenarios
- **Double tap**: Quick accept recommendation

### 2. Time Navigation

#### A. Prediction Time Slider
```swift
struct PredictionTimeSlider {
    let range: ClosedRange<TimeInterval> = 0...240 // 0-4 hours
    @State var selectedTime: TimeInterval = 60 // Default 1 hour
    
    var body: some View {
        Slider(value: $selectedTime, in: range) { _ in
            updatePredictionEmphasis()
        }
    }
}
```

#### B. Historical Pattern Overlay
Toggle to show:
- Same time yesterday
- Same day last week
- Average pattern for this time
- Best day in last month

## Implementation Architecture

### 1. Enhanced Chart Manager

```swift
extension GlucoseChartManager {
    // New properties
    private var predictionEmphasisLevel: EmphasisLevel = .high
    private var actionOverlayEnabled: Bool = true
    private var smartAnnotationsEnabled: Bool = true
    
    // New methods
    func generateEnhancedChart() -> Chart {
        var layers = [ChartLayer]()
        
        // Base layers (existing)
        layers.append(glucosePointsLayer)
        layers.append(treatmentLayer)
        
        // New prediction layers
        layers.append(predictionLayer(emphasis: predictionEmphasisLevel))
        layers.append(confidenceBandLayer())
        layers.append(actionIndicatorLayer())
        
        // Smart overlays
        if actionOverlayEnabled {
            layers.append(actionRecommendationLayer())
        }
        
        if smartAnnotationsEnabled {
            layers.append(annotationLayer())
        }
        
        return Chart(layers: layers)
    }
}
```

### 2. Action Recommendation Engine

```swift
class ActionRecommendationEngine {
    func generateRecommendations(
        current: GlucosePoint,
        predictions: [PredictionPoint],
        context: UserContext
    ) -> [ActionRecommendation] {
        
        var recommendations = [ActionRecommendation]()
        
        // Analyze prediction trajectory
        let trajectory = analyzeTrajectory(predictions)
        
        // Check for preventable highs
        if let preventableHigh = findPreventableHigh(trajectory) {
            recommendations.append(
                createCorrectionRecommendation(for: preventableHigh)
            )
        }
        
        // Check for preventable lows
        if let preventableLow = findPreventableLow(trajectory) {
            recommendations.append(
                createCarbRecommendation(for: preventableLow)
            )
        }
        
        // Pattern-based recommendations
        recommendations.append(contentsOf: 
            generatePatternBasedRecommendations(context)
        )
        
        return recommendations.sorted(by: { $0.urgency > $1.urgency })
    }
}
```

### 3. Visual Impact Calculator

```swift
class VisualImpactCalculator {
    func calculateActionImpact(
        action: ActionRecommendation,
        baseline: [PredictionPoint]
    ) -> [PredictionPoint] {
        
        switch action.type {
        case .correctionBolus(let units):
            return applyInsulinImpact(units, to: baseline)
            
        case .carbsNeeded(let grams):
            return applyCarbImpact(grams, to: baseline)
            
        case .activityAdjustment:
            return applyActivityImpact(to: baseline)
        }
    }
}
```

## UI Components

### 1. Prediction Control Panel

```swift
struct PredictionControlPanel: View {
    @Binding var emphasisLevel: EmphasisLevel
    @Binding var showConfidenceBands: Bool
    @Binding var showActionImpact: Bool
    @Binding var predictionHours: Double
    
    var body: some View {
        VStack {
            // Prediction time range
            HStack {
                Text("Prediction Range")
                Slider(value: $predictionHours, in: 1...6)
                Text("\(Int(predictionHours))h")
            }
            
            // Visual options
            Toggle("Show Confidence", isOn: $showConfidenceBands)
            Toggle("Show Action Impact", isOn: $showActionImpact)
            
            // Emphasis selector
            Picker("Emphasis", selection: $emphasisLevel) {
                Text("Low").tag(EmphasisLevel.low)
                Text("Medium").tag(EmphasisLevel.medium)
                Text("High").tag(EmphasisLevel.high)
            }
        }
    }
}
```

### 2. Action Summary Bar

```swift
struct ActionSummaryBar: View {
    let recommendations: [ActionRecommendation]
    
    var body: some View {
        HStack {
            ForEach(recommendations.prefix(3)) { action in
                ActionBadge(action: action)
                    .onTapGesture {
                        showActionDetail(action)
                    }
            }
            
            if recommendations.count > 3 {
                Text("+\(recommendations.count - 3) more")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}
```

## Visual Examples

### 1. Enhanced Prediction Line
```
Current BG: 120 mg/dL
     ↓
━━━●━━━━━━━┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅ (Baseline prediction)
   │      ╱┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ (With correction bolus)
   │     ╱
   │    ╱ 💉 2.5u recommended
   │   ╱
   └──┴────────────────────→ Time
     Now   +1h    +2h    +3h
```

### 2. Action Impact Visualization
```
250 ┤                    ⚠️ Predicted high
    │                  ╱┈┈┈┈ Without action
200 ┤                ╱╱
    │              ╱╱ ┈ ┈ ┈ With 3u bolus
150 ┤      ● ● ● ╱╱┈ ┈ ┈ ┈ ┈
    │    ╱     ╱💉
100 ┤  ╱     ╱  "Take 3u now"
    │╱     ╱
 50 ┤────────────────────────
    └────────────────────────→
     -2h    Now    +2h    +4h
```

### 3. Confidence Bands
```
200 ┤     ░░░░░░░░░░░░░░░ } Upper confidence
    │   ░░░      ░░░░░░░ }
150 ┤ ░░░  ━━━━━━━  ░░░░ } Predicted line
    │░░  ━━      ━━  ░░░ }
100 ┤░░━━          ━━░░░ } Lower confidence
    │━━              ━━░ }
 50 ┤────────────────────
```

## Settings and Customization

### User Preferences
```swift
struct PredictionGraphSettings {
    // Visual preferences
    var predictionOpacity: Double = 0.8
    var showConfidenceBands: Bool = true
    var animatePredictions: Bool = true
    var predictionLineStyle: LineStyle = .dashed
    
    // Recommendation preferences
    var showActionOverlays: Bool = true
    var maxRecommendations: Int = 3
    var minimumConfidence: Double = 0.7
    
    // Time preferences
    var defaultPredictionHours: Double = 2.0
    var showHistoricalOverlay: Bool = false
}
```

## Integration with MDI Loop

The enhanced graph serves as the visual component of the MDI loop system:

1. **Real-time Feedback**: Shows immediate impact of following recommendations
2. **Decision Support**: Visual comparison of action vs. no action
3. **Learning Display**: Shows how past actions affected outcomes
4. **Pattern Recognition**: Highlights recurring situations

## Performance Considerations

1. **Efficient Rendering**: Use Metal for smooth animations
2. **Smart Updates**: Only recalculate changed predictions
3. **Lazy Loading**: Load historical data on demand
4. **Caching**: Cache prediction calculations

## Success Metrics

1. **User Engagement**: Time spent viewing predictions
2. **Action Rate**: Percentage of recommendations followed
3. **Outcome Improvement**: TIR before/after implementation
4. **User Satisfaction**: Survey on graph usefulness

## Future Enhancements

1. **AR Mode**: Project predictions in augmented reality
2. **Voice Integration**: "Hey Siri, show my glucose prediction"
3. **Machine Learning**: Personalized prediction models
4. **Social Features**: Compare predictions with similar users