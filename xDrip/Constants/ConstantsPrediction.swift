import Foundation
import UIKit

/// Constants and configuration for glucose prediction features
enum ConstantsPrediction {
    
    // MARK: - Algorithm Configuration
    
    /// Enable the improved prediction algorithm (V2)
    static let useImprovedAlgorithm = true
    
    /// Minimum readings required for predictions
    static let minimumReadingsRequired = 3
    
    /// Optimal number of readings for best predictions
    static let optimalReadingsCount = 48 // 4 hours at 5-minute intervals
    
    /// Maximum lookback period for historical data (hours)
    static let maxLookbackHours = 12.0
    
    // MARK: - Time Windows
    
    /// Short-term trend window (minutes)
    static let shortTermWindowMinutes = 30
    
    /// Medium-term trend window (minutes)
    static let mediumTermWindowMinutes = 120
    
    /// Long-term trend window (minutes)
    static let longTermWindowMinutes = 360
    
    // MARK: - Prediction Display
    
    /// Default prediction line color
    static let defaultPredictionLineColor = UIColor.systemBlue.withAlphaComponent(0.7)
    
    /// Alternative prediction line color for high confidence
    static let highConfidencePredictionLineColor = UIColor.systemGreen.withAlphaComponent(0.7)
    
    /// Alternative prediction line color for low confidence
    static let lowConfidencePredictionLineColor = UIColor.systemOrange.withAlphaComponent(0.5)
    
    /// Prediction line width
    static let predictionLineWidth: CGFloat = 2.0
    
    /// Prediction line dash pattern
    static let predictionLineDashPattern: [NSNumber] = [6, 3]
    
    // MARK: - Performance Tuning
    
    /// Cache validity interval (seconds)
    static let featureCacheValidityInterval: TimeInterval = 60
    
    /// Maximum predictions to generate at once
    static let maxPredictionSteps = 48 // 4 hours at 5-minute intervals
    
    /// Background prediction update interval (seconds)
    static let backgroundUpdateInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Confidence Thresholds
    
    /// High confidence threshold
    static let highConfidenceThreshold = 0.8
    
    /// Low confidence threshold
    static let lowConfidenceThreshold = 0.5
    
    /// Minimum confidence to display prediction
    static let minimumConfidenceToDisplay = 0.3
    
    // MARK: - Physiological Constants
    
    /// Default insulin sensitivity (mg/dL per unit)
    static let defaultInsulinSensitivity = 40.0
    
    /// Default carb ratio (grams per unit)
    static let defaultCarbRatio = 10.0
    
    /// Default carb absorption rate (grams per hour)
    static let defaultCarbAbsorptionRate = 30.0
    
    /// Default carb absorption delay (minutes)
    static let defaultCarbAbsorptionDelay = 10.0
    
    // MARK: - Safety Limits
    
    /// Minimum allowed glucose value (mg/dL)
    static let minimumGlucoseValue = 40.0
    
    /// Maximum allowed glucose value (mg/dL)
    static let maximumGlucoseValue = 400.0
    
    /// Maximum rate of change (mg/dL per minute)
    static let maximumRateOfChange = 4.0
    
    // MARK: - Algorithm Weights
    
    /// Default weight for trend-based predictions
    static let defaultTrendWeight = 0.4
    
    /// Default weight for pattern-based predictions
    static let defaultPatternWeight = 0.3
    
    /// Default weight for physiological predictions
    static let defaultPhysiologicalWeight = 0.3
    
    // MARK: - Debug Settings
    
    /// Enable prediction algorithm logging
    static let enablePredictionLogging = false
    
    /// Enable performance metrics logging
    static let enablePerformanceLogging = false
    
    /// Save prediction accuracy metrics
    static let trackPredictionAccuracy = true
    
    // MARK: - Feature Flags
    
    /// Enable pattern matching predictions
    static let enablePatternMatching = true
    
    /// Enable machine learning predictions (future)
    static let enableMLPredictions = false
    
    /// Enable exercise impact predictions
    static let enableExercisePredictions = true
    
    /// Enable meal detection
    static let enableMealDetection = false
    
    // MARK: - Notification Settings
    
    /// Enable predictive low alerts
    static let enablePredictiveLowAlerts = true
    
    /// Predictive low threshold (mg/dL)
    static let predictiveLowThreshold = 70.0
    
    /// Predictive low time horizon (minutes)
    static let predictiveLowHorizonMinutes = 30
    
    /// Enable predictive high alerts
    static let enablePredictiveHighAlerts = true
    
    /// Predictive high threshold (mg/dL)
    static let predictiveHighThreshold = 180.0
    
    /// Predictive high time horizon (minutes)
    static let predictiveHighHorizonMinutes = 30
}