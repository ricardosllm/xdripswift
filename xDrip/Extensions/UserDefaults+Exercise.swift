//
//  UserDefaults+Exercise.swift
//  xdrip
//
//  Exercise-aware predictions feature flags and settings
//

import Foundation

extension UserDefaults {
    
    // MARK: - Exercise Feature Keys
    
    /// All exercise-related settings are namespaced to avoid conflicts
    private enum ExerciseKeys: String, CaseIterable {
        // Feature flags
        case exercisePredictionsEnabled = "exercise.predictions.enabled"
        case exerciseDataCollectionEnabled = "exercise.dataCollection.enabled"
        case showActivityOnChart = "exercise.chart.showActivity"
        case showExerciseInsights = "exercise.insights.enabled"
        
        // Privacy settings
        case healthKitPermissionRequested = "exercise.healthKit.permissionRequested"
        case healthKitPermissionGranted = "exercise.healthKit.permissionGranted"
        
        // Data settings
        case exerciseDataRetentionDays = "exercise.data.retentionDays"
        case exercisePredictionSensitivity = "exercise.predictions.sensitivity"
        
        // Advanced settings
        case exerciseDebugLogging = "exercise.debug.logging"
        case exerciseBackgroundProcessing = "exercise.background.enabled"
    }
    
    // MARK: - Feature Flags
    
    /// Master switch for exercise-aware predictions
    @objc dynamic var exercisePredictionsEnabled: Bool {
        get {
            // Default to false for backwards compatibility
            return bool(forKey: ExerciseKeys.exercisePredictionsEnabled.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.exercisePredictionsEnabled.rawValue)
            
            // If disabling, also disable dependent features
            if !newValue {
                exerciseDataCollectionEnabled = false
                showActivityOnChart = false
                showExerciseInsights = false
            }
        }
    }
    
    /// Whether to collect exercise data in the background
    @objc dynamic var exerciseDataCollectionEnabled: Bool {
        get {
            return bool(forKey: ExerciseKeys.exerciseDataCollectionEnabled.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.exerciseDataCollectionEnabled.rawValue)
        }
    }
    
    /// Whether to show activity indicators on the glucose chart
    @objc dynamic var showActivityOnChart: Bool {
        get {
            return bool(forKey: ExerciseKeys.showActivityOnChart.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.showActivityOnChart.rawValue)
        }
    }
    
    /// Whether to show exercise insights and recommendations
    @objc dynamic var showExerciseInsights: Bool {
        get {
            return bool(forKey: ExerciseKeys.showExerciseInsights.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.showExerciseInsights.rawValue)
        }
    }
    
    // MARK: - Privacy Settings
    
    /// Whether we've asked for HealthKit permission
    var healthKitPermissionRequested: Bool {
        get {
            return bool(forKey: ExerciseKeys.healthKitPermissionRequested.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.healthKitPermissionRequested.rawValue)
        }
    }
    
    /// Whether HealthKit permission was granted (cached value)
    var healthKitPermissionGranted: Bool {
        get {
            return bool(forKey: ExerciseKeys.healthKitPermissionGranted.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.healthKitPermissionGranted.rawValue)
        }
    }
    
    // MARK: - Data Settings
    
    /// How many days to retain exercise data (default: 30)
    var exerciseDataRetentionDays: Int {
        get {
            let days = integer(forKey: ExerciseKeys.exerciseDataRetentionDays.rawValue)
            return days > 0 ? days : 30 // Default to 30 days
        }
        set {
            set(max(1, min(365, newValue)), forKey: ExerciseKeys.exerciseDataRetentionDays.rawValue)
        }
    }
    
    /// Sensitivity of exercise impact on predictions (0.0 to 2.0, default: 1.0)
    var exercisePredictionSensitivity: Double {
        get {
            let sensitivity = double(forKey: ExerciseKeys.exercisePredictionSensitivity.rawValue)
            return sensitivity > 0 ? sensitivity : 1.0 // Default to 1.0
        }
        set {
            set(max(0.0, min(2.0, newValue)), forKey: ExerciseKeys.exercisePredictionSensitivity.rawValue)
        }
    }
    
    // MARK: - Advanced Settings
    
    /// Whether to enable debug logging for exercise features
    var exerciseDebugLogging: Bool {
        get {
            return bool(forKey: ExerciseKeys.exerciseDebugLogging.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.exerciseDebugLogging.rawValue)
        }
    }
    
    /// Whether to process exercise data in the background
    var exerciseBackgroundProcessing: Bool {
        get {
            return bool(forKey: ExerciseKeys.exerciseBackgroundProcessing.rawValue)
        }
        set {
            set(newValue, forKey: ExerciseKeys.exerciseBackgroundProcessing.rawValue)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Reset all exercise-related settings to defaults
    func resetExerciseSettings() {
        for key in ExerciseKeys.allCases {
            removeObject(forKey: key.rawValue)
        }
    }
    
    /// Check if exercise features are available (all prerequisites met)
    var exerciseFeaturesAvailable: Bool {
        // For now, just check if iOS 13+ (for HealthKit background delivery)
        if #available(iOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
}