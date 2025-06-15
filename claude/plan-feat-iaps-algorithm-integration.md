# iAPS Algorithm Integration Plan for xDripSwift

## Overview
This plan details how to integrate iAPS's proven glucose prediction algorithms into xDripSwift by copying core modules and adapting them to work within xDripSwift's architecture.

## Core Modules to Copy from iAPS

### 1. Core Data Models (Direct Copy)
```
From: iAPS/FreeAPS/Sources/Models/
To: xdrip/Models/iAPS/

Files to copy:
- IOBEntry.swift           # IOB data structure with basal/bolus breakdown
- Suggestion.swift         # Contains Predictions struct (IOB/COB/ZT/UAM arrays)
- Autosens.swift          # Insulin sensitivity adjustments
- CarbsEntry.swift        # Carb data model
- BloodGlucose.swift      # Glucose data model
```

### 2. JavaScript Algorithm Engine (Core Algorithm)
```
From: iAPS/FreeAPS/Sources/APS/OpenAPS/
To: xdrip/Managers/APSAlgorithm/

Files to copy:
- JavaScriptWorker.swift   # JS execution engine using JavaScriptCore
- OpenAPS.swift           # Main algorithm orchestrator (strip down for our needs)
- Constants.swift         # Algorithm constants

From: iAPS/FreeAPS/Resources/javascript/prepare/
To: xdrip/Resources/javascript/

JavaScript files:
- iob.js                  # IOB calculations with insulin curves
- determine-basal.js      # Main prediction algorithm
- autosens.js            # Sensitivity calculations
- meal.js                # COB calculations with absorption curves
```

### 3. Storage Layer (Partial Copy/Adapt)
```
From: iAPS/FreeAPS/Sources/APS/Storage/
To: xdrip/Managers/APSStorage/

Key interfaces to adapt:
- PumpHistoryStorage protocol → Map to TreatmentEntry
- CarbsStorage protocol → Map to TreatmentEntry (carbs)
- GlucoseStorage protocol → Map to BgReading
```

## Integration Architecture

### Main Prediction Manager
```swift
// xdrip/Managers/Prediction/iAPSPredictionManager.swift
class iAPSPredictionManager {
    private let jsWorker: JavaScriptWorker
    private let openAPS: OpenAPSLite  // Stripped down version
    private let coreDataManager: CoreDataManager
    
    func generatePredictions(
        glucose: [BgReading],
        treatments: [TreatmentEntry],
        profile: UserProfile
    ) -> PredictionResult {
        // 1. Convert xDripSwift data to iAPS format
        let glucoseData = convertGlucoseToiAPSFormat(glucose)
        let pumpHistory = convertTreatmentsToiAPSFormat(treatments)
        
        // 2. Run JavaScript IOB calculation
        let iobData = jsWorker.executeScript(
            "iob",
            params: [pumpHistory, profile, clock]
        )
        
        // 3. Run JavaScript meal calculation
        let mealData = jsWorker.executeScript(
            "meal",
            params: [pumpHistory, profile, basalProfile, clock, carbs]
        )
        
        // 4. Run main prediction algorithm
        let predictions = jsWorker.executeScript(
            "determine-basal",
            params: [glucose, currentTemp, iobData, profile, autosens, mealData]
        )
        
        // 5. Extract prediction arrays
        return PredictionResult(
            iob: predictions.predBGs.IOB,    // Array of mg/dL values
            cob: predictions.predBGs.COB,    // Array of mg/dL values
            zt: predictions.predBGs.ZT,      // Zero temp predictions
            uam: predictions.predBGs.UAM     // Unannounced meal predictions
        )
    }
}
```

### Data Converters
```swift
// xdrip/Managers/Prediction/iAPSDataConverter.swift
class iAPSDataConverter {
    // Convert BgReading → iAPS glucose format
    func convertGlucoseToiAPSFormat(_ readings: [BgReading]) -> [[String: Any]] {
        return readings.map { reading in
            [
                "dateString": ISO8601DateFormatter().string(from: reading.timeStamp),
                "sgv": reading.calculatedValue,
                "direction": reading.slopeArrow,
                "device": "xDrip",
                "type": "sgv"
            ]
        }
    }
    
    // Convert TreatmentEntry → iAPS pumphistory format
    func convertTreatmentsToiAPSFormat(_ treatments: [TreatmentEntry]) -> [[String: Any]] {
        return treatments.compactMap { treatment in
            switch treatment.treatmentType {
            case .Insulin:
                return [
                    "_type": "Bolus",
                    "timestamp": ISO8601DateFormatter().string(from: treatment.date),
                    "amount": treatment.value,
                    "duration": 0
                ]
            case .Carbs:
                return [
                    "_type": "Carbs",
                    "timestamp": ISO8601DateFormatter().string(from: treatment.date),
                    "carbs": treatment.value,
                    "absorptionTime": 180 // Default 3 hours
                ]
            default:
                return nil
            }
        }
    }
}
```

## Key Functions to Use

### From OpenAPS.swift:
- `iob(pumphistory:profile:clock:autosens:)` - Calculate insulin on board
- `meal(pumphistory:profile:basalProfile:clock:carbs:glucose:)` - Calculate carbs on board
- `determineBasal(glucose:currentTemp:iob:profile:autosens:meal:)` - Main prediction algorithm

### From JavaScript (via JavaScriptWorker):
- `freeaps_iob()` - IOB calculation with exponential curves
- `determine_basal()` - Generates 4 prediction arrays (IOB/COB/ZT/UAM)
- `meal()` - Carb absorption with linear/nonlinear models

## Chart Integration

### Update GlucoseChartManager
```swift
// xdrip/Managers/Charts/GlucoseChartManager.swift
extension GlucoseChartManager {
    private func generateiAPSPredictionChartPoints() {
        guard UserDefaults.standard.showiAPSPredictions else { return }
        
        // Get recent data
        let glucose = bgReadingsAccessor.getLatestBgReadings(limit: 48, howOld: nil)
        let treatments = treatmentEntryAccessor.getTreatments(...)
        
        // Generate predictions
        let predictions = iAPSPredictionManager.generatePredictions(
            glucose: glucose,
            treatments: treatments,
            profile: getCurrentUserProfile()
        )
        
        // Create chart points for each prediction type
        iobPredictionChartPoints = createPredictionChartPoints(
            predictions.iob,
            color: .systemPurple,
            label: "IOB"
        )
        
        cobPredictionChartPoints = createPredictionChartPoints(
            predictions.cob,
            color: .systemOrange,
            label: "COB"
        )
        
        uamPredictionChartPoints = createPredictionChartPoints(
            predictions.uam,
            color: .systemRed,
            label: "UAM"
        )
    }
    
    private func createPredictionChartPoints(
        _ values: [Int],
        color: UIColor,
        label: String
    ) -> [ChartPoint] {
        let startTime = Date()
        return values.enumerated().map { index, mgdl in
            let time = startTime.addingTimeInterval(Double(index * 5 * 60)) // 5 min intervals
            let value = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? 
                Double(mgdl) : Double(mgdl).mgDlToMmol()
            
            return ChartPoint(
                x: ChartAxisValueDate(date: time, formatter: axisLabelTimeFormatter),
                y: ChartAxisValueDouble(value)
            )
        }
    }
}
```

## What the Prediction Lines Represent

Based on iAPS code analysis, the predictions show **future glucose values** (not effects):

- **IOB line (Purple)**: Predicted glucose considering only active insulin
  - Shows how low glucose might go if no carbs are consumed
  - Accounts for both basal and bolus insulin

- **COB line (Orange)**: Predicted glucose considering carbs + insulin
  - Shows expected glucose trajectory with current carbs on board
  - Uses linear or nonlinear absorption models

- **ZT line (Blue)**: Zero-temp prediction
  - Shows glucose if basal insulin was stopped now
  - Useful for preventing lows

- **UAM line (Red)**: Unannounced meal detection
  - Detects and predicts impact of unlogged carbs
  - Based on glucose momentum and deviations

## Implementation Steps

### Phase 1: Core Infrastructure (Week 1)
1. Copy data models from iAPS
2. Set up JavaScript execution environment
3. Copy and bundle JavaScript algorithms
4. Create data converter classes

### Phase 2: Algorithm Integration (Week 2)
1. Implement stripped-down OpenAPS class
2. Test IOB calculations against known values
3. Test COB calculations
4. Verify prediction generation

### Phase 3: xDripSwift Integration (Week 3)
1. Create iAPSPredictionManager
2. Add settings for prediction options
3. Update GlucoseChartManager
4. Add prediction lines to chart

### Phase 4: Testing & Validation (Week 4)
1. Unit tests for each component
2. Integration tests with real data
3. Compare predictions with iAPS app
4. User acceptance testing

## Settings to Add

```swift
// UserDefaults extensions
extension UserDefaults {
    // Master toggle
    case showiAPSPredictions = "showiAPSPredictions"
    
    // Individual prediction lines
    case showIOBPrediction = "showIOBPrediction"
    case showCOBPrediction = "showCOBPrediction"
    case showUAMPrediction = "showUAMPrediction"
    case showZTPrediction = "showZTPrediction"
    
    // Algorithm settings
    case enableAutosens = "enableAutosens"
    case carbAbsorptionModel = "carbAbsorptionModel" // linear/nonlinear
}
```

## Testing Strategy

### Unit Tests
```swift
class iAPSAlgorithmTests: XCTestCase {
    func testIOBCalculation() {
        // Test with known insulin doses
        // Verify exponential decay curve
    }
    
    func testCOBCalculation() {
        // Test with known carb entries
        // Verify absorption curves
    }
    
    func testPredictionGeneration() {
        // Test with sample data
        // Verify 4 prediction arrays generated
        // Check values are within physiological bounds
    }
}
```

### Integration Tests
- Compare predictions with iAPS app using same data
- Verify chart displays all prediction lines
- Test with edge cases (no IOB, no COB, etc.)

## Benefits of This Approach

1. **Proven Algorithms**: Using exact same calculations as iAPS/OpenAPS
2. **Maintained Compatibility**: Can update algorithms from iAPS upstream
3. **Multiple Scenarios**: Shows different possible glucose futures
4. **Accurate Calculations**: Includes all physiological effects
5. **No Reinventing**: Leveraging years of OpenAPS development

## Potential Challenges

1. **JavaScript Performance**: May need optimization for iOS
2. **Data Format Conversion**: Mapping between xDripSwift and iAPS formats
3. **Memory Usage**: Multiple prediction arrays updated frequently
4. **UI Complexity**: Showing 4+ prediction lines clearly

## Future Enhancements

1. Add autosens (automatic sensitivity detection)
2. Add autoISF (automatic ISF adjustments)
3. Add meal detection algorithms
4. Add exercise impact predictions
5. Integration with Apple Watch complications