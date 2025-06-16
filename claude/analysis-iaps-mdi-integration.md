# iAPS Analysis and MDI Integration Plan for xdripswift

## Executive Summary

iAPS (FreeAPS) is an iOS artificial pancreas system that implements OpenAPS algorithms for automated insulin delivery. This analysis identifies key components that can be adapted for MDI (Multiple Daily Injections) use in xdripswift, focusing on bolus calculations, glucose predictions, and insulin sensitivity adjustments without pump automation.

## Key iAPS Components for MDI Integration

### 1. Advanced Bolus Calculator
The iAPS bolus calculator (`BolusStateModel.swift`) provides sophisticated insulin dosing calculations that consider:

- **Current BG vs Target**: Correction insulin based on glucose deviation
- **Trend Analysis**: 15-minute glucose trend adjustments
- **Carb Coverage**: Insulin for carbohydrates on board (COB)
- **Active Insulin**: IOB-based dose reductions
- **Custom Factors**: User-adjustable correction factors
- **Fatty Meal Support**: Extended absorption patterns

**MDI Adaptation**: This calculator can be directly integrated for meal bolus and correction dose recommendations.

### 2. OpenAPS Algorithm Integration
iAPS uses JavaScriptCore to run OpenAPS algorithms, providing:

- **Glucose Predictions**: Multiple prediction curves (IOB, ZT, COB, UAM)
- **Insulin Sensitivity Detection**: Autosens adjusts ISF based on patterns
- **Meal Detection**: Unannounced meal absorption (UAM) detection

**MDI Adaptation**: Extract prediction algorithms for glucose forecasting without basal rate adjustments.

### 3. AutoISF (Automatic Insulin Sensitivity Factor)
Dynamic ISF adjustments based on:

- **BG Acceleration/Deceleration**: Adjusts sensitivity during rapid changes
- **Post-Meal Patterns**: Different ISF weights after meals
- **IOB Thresholds**: Sensitivity changes based on active insulin
- **Time-based Adjustments**: Hourly ISF variation support

**MDI Adaptation**: Crucial for accurate bolus calculations in changing conditions.

### 4. Comprehensive Data Models

#### CarbsEntry Model
```swift
- Timestamp tracking
- Carb, fat, protein amounts
- FPU (Fat Protein Unit) support
- Note field for meal context
```

#### IOB Tracking
- Real-time insulin on board calculations
- Decay curves based on insulin type
- Historical bolus integration

#### Glucose Management
- Multiple source support (CGM, manual)
- Trend calculation algorithms
- Prediction integration

## Proposed MDI Features for xdripswift

### Phase 1: Core Bolus Calculator
1. **Implement Basic Bolus Calculator**
   - Port `calculateInsulin()` logic from iAPS
   - Add UI for entering carbs and current BG
   - Display dose breakdown (correction + meal)

2. **IOB Tracking System**
   - Create insulin entry storage
   - Implement decay curves (configurable DIA)
   - Real-time IOB display

3. **Settings Management**
   - ISF, CR, target BG schedules
   - Custom correction factors
   - Insulin action profiles

### Phase 2: Advanced Features
1. **Glucose Predictions**
   - Port OpenAPS prediction algorithms
   - Display prediction curves in charts
   - Alert for predicted lows/highs

2. **AutoISF Integration**
   - Dynamic ISF based on glucose patterns
   - Configurable adjustment weights
   - Historical analysis for tuning

3. **Meal Tracking**
   - Carb entry with fat/protein
   - FPU calculations for extended boluses
   - Meal history and patterns

### Phase 3: MDI-Specific Enhancements
1. **Basal Insulin Advisor**
   - Convert pump basal suggestions to long-acting doses
   - Track basal insulin injections
   - Adjust for missed doses

2. **Smart Reminders**
   - Injection time notifications
   - Missed dose alerts
   - Pre-meal bolus timing

3. **MDI Reports**
   - Daily insulin summary
   - Injection site rotation tracker
   - Time-in-range analytics

## Technical Implementation Strategy

### 1. Architecture Integration
```
xdripswift/
├── Managers/
│   ├── MDI/
│   │   ├── MDIBolusCalculator.swift
│   │   ├── MDIInsulinManager.swift
│   │   ├── MDIIOBCalculator.swift
│   │   └── MDIAutoISFManager.swift
│   └── Prediction/
│       └── MDIPredictionManager.swift
├── Models/
│   ├── MDIBolus.swift
│   ├── MDISettings.swift
│   └── InsulinProfile.swift
└── Views/
    ├── MDIBolusView.swift
    ├── MDISettingsView.swift
    └── MDIReportsView.swift
```

### 2. Core Data Schema
- Add tables for insulin injections
- Track injection sites and types
- Store meal data with extended attributes

### 3. Algorithm Adaptation
- Extract JavaScript algorithms to Swift
- Remove pump-specific logic
- Add MDI-specific validations

### 4. User Interface
- New tab for MDI features
- Quick bolus calculator access
- Injection history view
- Settings for MDI parameters

## Key Differences from Pump-based Systems

1. **No Automated Delivery**: All insulin must be manually injected
2. **Basal Considerations**: Long-acting insulin instead of variable basal rates
3. **Correction Timing**: Limited by injection frequency vs continuous delivery
4. **Site Rotation**: Track injection locations for MDI users
5. **Pen Integration**: Support for smart pen data if available

## Risk Mitigation

1. **Clear MDI Labeling**: Ensure users understand this is for MDI, not pump therapy
2. **Conservative Defaults**: Start with less aggressive correction factors
3. **Education Integration**: Include MDI-specific guidance and warnings
4. **Healthcare Provider Mode**: Allow HCP review of settings

## Development Priorities

1. **High Priority**
   - Basic bolus calculator
   - IOB tracking
   - Carb entry interface

2. **Medium Priority**
   - Glucose predictions
   - AutoISF implementation
   - Meal pattern analysis

3. **Low Priority**
   - Smart pen integration
   - Advanced reporting
   - Cloud backup

## Conclusion

iAPS provides a robust foundation for advanced diabetes management algorithms. By adapting its core calculation and prediction capabilities for MDI use, xdripswift can offer sophisticated decision support tools for users who don't have or don't want insulin pumps. The phased approach allows for incremental development while maintaining safety and usability.

## Next Steps

1. Create detailed technical specifications for Phase 1
2. Design UI mockups for MDI features
3. Set up development branch for MDI integration
4. Begin porting core calculation algorithms
5. Establish testing protocols for MDI features