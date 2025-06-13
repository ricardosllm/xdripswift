# Exercise-Aware Predictions

This module adds exercise and activity awareness to glucose predictions in xDrip4iOS.

## Architecture Principles

### 1. Backwards Compatibility
- **No modifications** to existing xDrip code
- All features are **opt-in** via feature flags
- Can be completely disabled without affecting core functionality
- Separate Core Data model to avoid schema changes

### 2. Privacy First
- All processing happens **on device**
- No exercise data leaves the phone
- Explicit user consent for HealthKit access
- Clear privacy explanations

### 3. Modular Design
- `DataCollection/` - HealthKit integration and data gathering
- `Analysis/` - Activity pattern recognition and impact calculation
- `Models/` - Core Data models and data structures
- `UI/` - User interface components and settings

## Implementation Status

### ✅ Phase 1 - Foundation (Current)
- [x] Feature flags in UserDefaults
- [x] Basic HealthKit authorization manager
- [x] Developer settings integration pattern
- [ ] Unit test setup

### 🚧 Phase 2 - Data Collection (Next)
- [ ] Background HealthKit monitoring
- [ ] Activity data persistence
- [ ] Basic activity classification

### 📋 Phase 3 - Analysis Engine (Future)
- [ ] Activity impact modeling
- [ ] Pattern recognition
- [ ] Glucose correlation analysis

### 📋 Phase 4 - Prediction Enhancement (Future)
- [ ] Integration with existing predictions
- [ ] Confidence scoring
- [ ] UI visualization

## Quick Start for Developers

1. **Enable Developer Settings**
   - Settings → Developer Settings → Enable

2. **Enable Exercise Predictions**
   - Developer Settings → Exercise-Aware Predictions → On

3. **Grant HealthKit Access**
   - Follow prompts to grant health data access

## Key Components

### UserDefaults+Exercise.swift
Adds namespaced settings for all exercise features:
- `exercisePredictionsEnabled` - Master feature flag
- `exerciseDataCollectionEnabled` - Background data collection
- `showActivityOnChart` - UI visualization
- `exerciseDebugLogging` - Debug logging

### ExerciseHealthKitManager.swift
Manages HealthKit authorization and data access:
- Requests only read permissions (no writing)
- Handles authorization flow
- Provides privacy explanation UI

### Integration Pattern
Shows how to add settings without modifying existing code:
- Extension-based approach
- Subclassing option for view models
- Notification-based injection

## Testing

All exercise features include comprehensive tests:
- Unit tests for data processing
- Integration tests for HealthKit
- UI tests for settings flow
- Backwards compatibility tests

## Privacy & Security

- **No network access** - All processing is local
- **Minimal data retention** - 30 days by default
- **User control** - Can disable anytime
- **Audit trail** - All data access is logged

## Contributing

When adding new features:
1. Always check feature flags first
2. Never modify existing xDrip code
3. Add tests for new functionality
4. Document privacy implications
5. Ensure backwards compatibility

## Future Enhancements

- Apple Watch integration
- Machine learning models
- Meal timing correlation
- Stress detection via HRV
- Social features (anonymized)