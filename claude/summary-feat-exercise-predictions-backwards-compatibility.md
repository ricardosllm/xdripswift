# Exercise Predictions: Backwards Compatibility & Minimal Change Strategy

## Overview

This document outlines strategies to implement exercise-aware predictions while maintaining 100% backwards compatibility and minimizing changes to existing xDripSwift code.

## Core Principles

### 1. Extension Over Modification
- **Never modify existing method signatures**
- **Add new methods rather than changing existing ones**
- **Use protocol extensions for new functionality**
- **Preserve all existing APIs**

### 2. Feature Flag Everything
- **All new features behind UserDefaults flags**
- **Gradual rollout capabilities**
- **Easy rollback without code changes**
- **A/B testing support**

### 3. Dependency Injection
- **New components injected, not hardcoded**
- **Existing code paths unchanged when feature disabled**
- **Clean separation of concerns**

## Integration Strategy

### 1. PredictionManager Integration

#### Current Code (Unchanged)
```swift
// Existing PredictionManager remains completely unchanged
class PredictionManager {
    func getPredictedBgReadings() -> [BgReading] {
        // Existing implementation stays exactly the same
        return calculatePredictions()
    }
}
```

#### New Extension (Additive Only)
```swift
// New file: PredictionManager+Exercise.swift
extension PredictionManager {
    // New property using associated objects (no class modification)
    private var exerciseEnhancer: ExerciseAwarePredictionEnhancer? {
        get { objc_getAssociatedObject(self, &exerciseEnhancerKey) as? ExerciseAwarePredictionEnhancer }
        set { objc_setAssociatedObject(self, &exerciseEnhancerKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    // New method that wraps existing functionality
    func getPredictedBgReadingsWithExerciseAwareness() -> [BgReading] {
        let basePredictions = getPredictedBgReadings() // Calls existing method
        
        guard UserDefaults.standard.exerciseAwarePredictionsEnabled else {
            return basePredictions // Feature flag check
        }
        
        if exerciseEnhancer == nil {
            exerciseEnhancer = ExerciseAwarePredictionEnhancer()
        }
        
        return exerciseEnhancer?.enhance(basePredictions) ?? basePredictions
    }
}
```

### 2. GlucoseChartManager Integration

#### Strategy: Decorator Pattern
```swift
// New file: GlucoseChartManager+Exercise.swift
class ExerciseAwareGlucoseChartManager {
    private let baseManager: GlucoseChartManager
    private let activityOverlay: ActivityOverlayManager?
    
    init(baseManager: GlucoseChartManager) {
        self.baseManager = baseManager
        self.activityOverlay = UserDefaults.standard.showActivityOnChart ? 
            ActivityOverlayManager() : nil
    }
    
    // Delegates all calls to base manager, adds overlays if enabled
    func glucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        guard var chart = baseManager.glucoseChartWithFrame(frame) else { return nil }
        
        if let overlay = activityOverlay {
            // Add activity indicators without modifying base chart
            chart = overlay.addActivityIndicators(to: chart)
        }
        
        return chart
    }
}
```

### 3. RootViewController Integration

#### Current Code Path (Preserved)
```swift
// Existing update method remains unchanged
private func updateGlucoseChart() {
    // Current implementation
    let predictions = predictionsManager.getPredictedBgReadings()
    // ... rest of existing code
}
```

#### New Parallel Path (Opt-in)
```swift
// Extension adds new method without touching existing one
extension RootViewController {
    @objc private func updateGlucoseChartWithExerciseAwareness() {
        if UserDefaults.standard.exerciseAwarePredictionsEnabled {
            // New path
            let predictions = predictionsManager.getPredictedBgReadingsWithExerciseAwareness()
            updateChartWithPredictions(predictions)
        } else {
            // Falls back to original method
            updateGlucoseChart()
        }
    }
    
    // Override viewDidLoad in extension to swap method if feature enabled
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UserDefaults.standard.exerciseAwarePredictionsEnabled {
            // Swap update timer to use new method
            setupExerciseAwareUpdateTimer()
        }
    }
}
```

## Data Model Strategy

### 1. Core Data Backwards Compatibility

#### New Entities (Separate Schema)
```swift
// New file: ExerciseModel.xcdatamodeld
// Completely separate Core Data model for exercise data
// Does NOT modify existing xDripSwift.xcdatamodeld

@objc(ActivitySession)
public class ActivitySession: NSManagedObject {
    // New entity in separate model
}

// Separate persistent container
class ExerciseDataManager {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ExerciseModel")
        // Separate SQLite file: ExerciseModel.sqlite
        return container
    }()
}
```

#### Linking Without Foreign Keys
```swift
// Use timestamps and loose coupling instead of Core Data relationships
extension ActivitySession {
    func glucoseReadings(in context: NSManagedObjectContext) -> [BgReading] {
        // Query by time range, no direct relationships
        let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        request.predicate = NSPredicate(
            format: "timeStamp >= %@ AND timeStamp <= %@",
            startTime as NSDate,
            endTime.addingTimeInterval(3600) as NSDate
        )
        return try? context.fetch(request) ?? []
    }
}
```

### 2. UserDefaults Strategy

#### Namespaced Settings
```swift
extension UserDefaults {
    // All new settings under exercise namespace
    private enum ExerciseKeys: String {
        case enabled = "exercise.predictions.enabled"
        case sensitivity = "exercise.predictions.sensitivity"
        case showOnChart = "exercise.predictions.showOnChart"
        case dataRetention = "exercise.predictions.dataRetentionDays"
    }
    
    // Existing UserDefaults extensions untouched
    // New computed properties for exercise features
    var exerciseAwarePredictionsEnabled: Bool {
        get { bool(forKey: ExerciseKeys.enabled.rawValue) }
        set { set(newValue, forKey: ExerciseKeys.enabled.rawValue) }
    }
}
```

## UI Integration Strategy

### 1. Settings Screen (Additive Only)

#### New Section Injection
```swift
// SettingsViewController+Exercise.swift
extension SettingsViewController {
    // Inject new section without modifying existing sections
    override func numberOfSections(in tableView: UITableView) -> Int {
        var sections = super.numberOfSections(in: tableView)
        if UserDefaults.standard.showDeveloperSettings {
            sections += 1 // Add exercise section only in dev mode initially
        }
        return sections
    }
    
    // Handle new section without touching existing code
    override func tableView(_ tableView: UITableView, 
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section < originalSectionCount {
            return super.tableView(tableView, cellForRowAt: indexPath)
        } else {
            // Handle exercise settings section
            return exerciseSettingsCell(for: indexPath)
        }
    }
}
```

### 2. Chart Overlays (Non-Invasive)

```swift
// New overlay system that doesn't modify existing chart
class ActivityOverlayView: UIView {
    // Transparent overlay on top of existing chart
    override func draw(_ rect: CGRect) {
        guard let chartView = superview?.subviews.first(where: { $0 is ChartView }) else { return }
        
        // Draw activity indicators on overlay
        // Original chart remains untouched underneath
    }
}

extension RootViewController {
    private func addActivityOverlayIfEnabled() {
        guard UserDefaults.standard.showActivityOnChart else { return }
        
        if activityOverlay == nil {
            activityOverlay = ActivityOverlayView(frame: chartContainerView.bounds)
            activityOverlay.isUserInteractionEnabled = false
            chartContainerView.addSubview(activityOverlay)
        }
    }
}
```

## Testing Strategy

### 1. Parallel Test Suites
```swift
// Existing tests remain unchanged
class PredictionManagerTests: XCTestCase {
    // All existing tests continue to pass
}

// New test suite for exercise features
class ExercisePredictionTests: XCTestCase {
    override func setUp() {
        // Enable feature flag for these tests only
        UserDefaults.standard.exerciseAwarePredictionsEnabled = true
    }
    
    override func tearDown() {
        // Reset to ensure no impact on other tests
        UserDefaults.standard.exerciseAwarePredictionsEnabled = false
    }
}
```

### 2. Backwards Compatibility Tests
```swift
class BackwardsCompatibilityTests: XCTestCase {
    func testPredictionsUnchangedWhenDisabled() {
        UserDefaults.standard.exerciseAwarePredictionsEnabled = false
        
        let manager = PredictionManager()
        let oldMethod = manager.getPredictedBgReadings()
        let newMethod = manager.getPredictedBgReadingsWithExerciseAwareness()
        
        XCTAssertEqual(oldMethod, newMethod, "Should be identical when disabled")
    }
    
    func testNoSideEffectsWhenDisabled() {
        UserDefaults.standard.exerciseAwarePredictionsEnabled = false
        
        // Ensure no HealthKit permissions requested
        // Ensure no background tasks scheduled
        // Ensure no additional Core Data queries
    }
}
```

## Migration Strategy

### Phase 1: Silent Integration (Weeks 1-4)
- Code merged but all features disabled by default
- No user-visible changes
- Allows testing in production without risk

### Phase 2: Developer Preview (Weeks 5-8)
- Enable in developer settings only
- Gather feedback from technical users
- Monitor for any performance impacts

### Phase 3: Opt-in Beta (Weeks 9-12)
- Add toggle in main settings (off by default)
- In-app messaging about new feature
- Collect telemetry (with consent)

### Phase 4: Gradual Rollout (Weeks 13-16)
- A/B testing with small percentage
- Monitor key metrics
- Gradually increase rollout percentage

## Rollback Strategy

### Feature Flag Kill Switch
```swift
// Remote configuration support
class FeatureFlags {
    static func checkRemoteFlags() {
        // Check for kill switch
        if RemoteConfig.shared.bool(forKey: "exercise.predictions.kill_switch") {
            UserDefaults.standard.exerciseAwarePredictionsEnabled = false
            // Clean up any background tasks
            ExerciseDataCollector.shared.stopAllMonitoring()
        }
    }
}
```

### Data Cleanup
```swift
extension ExerciseDataManager {
    func cleanupIfDisabled() {
        guard !UserDefaults.standard.exerciseAwarePredictionsEnabled else { return }
        
        // Stop all monitoring
        healthKitManager.stopAllObservers()
        
        // Optionally clean up data
        if UserDefaults.standard.exerciseDataCleanupOnDisable {
            try? FileManager.default.removeItem(at: exerciseDataURL)
        }
    }
}
```

## Performance Considerations

### 1. Lazy Initialization
```swift
// Don't initialize exercise components unless needed
class ExerciseAwarePredictionEnhancer {
    private lazy var healthKitManager: HealthKitManager = {
        // Only created when first accessed
        return HealthKitManager()
    }()
    
    private lazy var activityAnalyzer: ActivityAnalyzer = {
        // Only created if predictions requested
        return ActivityAnalyzer()
    }()
}
```

### 2. Conditional Compilation
```swift
#if EXERCISE_PREDICTIONS
    // Exercise prediction code only compiled if flag set
    import HealthKit
    import CoreMotion
#endif
```

### 3. Background Task Management
```swift
// Piggyback on existing background tasks
extension BluetoothPeripheralManager {
    // Existing background task
    private func backgroundTask() {
        // Existing code...
        
        // Only add exercise processing if enabled and already processing
        if UserDefaults.standard.exerciseAwarePredictionsEnabled,
           UIApplication.shared.applicationState == .background {
            ExerciseDataCollector.shared.processRecentActivityIfNeeded()
        }
    }
}
```

## Code Organization

### Directory Structure
```
xDrip/
├── Existing Folders (unchanged)
├── Extensions/
│   ├── PredictionManager+Exercise.swift
│   ├── GlucoseChartManager+Exercise.swift
│   └── UserDefaults+Exercise.swift
├── ExercisePredictions/
│   ├── DataCollection/
│   │   ├── ExerciseDataCollector.swift
│   │   └── HealthKitManager.swift
│   ├── Analysis/
│   │   ├── ActivityAnalyzer.swift
│   │   └── ExerciseGlucoseModel.swift
│   ├── Models/
│   │   ├── ExerciseModel.xcdatamodeld
│   │   └── ActivitySession+CoreDataClass.swift
│   └── UI/
│       ├── ActivityOverlayView.swift
│       └── ExerciseSettingsViewModel.swift
```

## API Stability Guarantees

### Public API Contract
```swift
// Document all public APIs that other parts might depend on
public protocol ExercisePredictionAPI {
    // Version 1.0 - These methods will not change
    func isEnabled() -> Bool
    func enhancePredictions(_ predictions: [BgReading]) -> [BgReading]
    func getRecentActivity() -> ActivitySummary?
}

// Deprecation strategy for future changes
@available(*, deprecated, message: "Use enhancePredictionsV2")
func enhancePredictions(_ predictions: [BgReading]) -> [BgReading]
```

## Summary

This backwards compatibility strategy ensures:

1. **Zero Breaking Changes**: All existing code paths remain functional
2. **Gradual Adoption**: Features can be enabled/disabled at runtime
3. **Easy Rollback**: Can disable features without code deployment
4. **Clean Separation**: New code in separate files/modules
5. **Performance Safety**: No impact when features disabled
6. **Testing Confidence**: Existing tests continue to pass

By following these patterns, we can add sophisticated exercise-aware predictions while maintaining the stability and reliability that users depend on for their diabetes management.

---

*Document Version: 1.0*  
*Last Updated: 2024-12-06*  
*Author: xDripSwift Development Team*