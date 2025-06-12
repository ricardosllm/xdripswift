import Foundation
import Accelerate
import os.log

/// Enhanced prediction manager that can be swapped in for the existing PredictionManager
/// This version implements the improved algorithms while maintaining the same interface
public class PredictionManagerV2: NSObject {
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let trace = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryPrediction)
    
    // Cache for performance
    private var featureCache: [Date: TimeSeriesFeatures] = [:]
    private let cacheValidityInterval: TimeInterval = 60 // 1 minute
    
    // Algorithm selection
    private var algorithmWeights: AlgorithmWeights = AlgorithmWeights()
    
    // MARK: - Initialization
    
    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        super.init()
    }
    
    // MARK: - Public Interface (Compatible with existing PredictionManager)
    
    /// Generates glucose predictions - main entry point
    public func generatePredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int = 5
    ) -> [PredictionPoint] {
        
        // Quick validation
        guard readings.count >= 3 else {
            os_log("Insufficient readings for prediction", log: trace, type: .info)
            return []
        }
        
        // Use improved algorithm if enough data, otherwise fallback
        if readings.count >= 12 {
            return generateImprovedPredictions(
                readings: readings,
                timeHorizon: timeHorizon,
                intervalMinutes: intervalMinutes
            )
        } else {
            return generateSimplePredictions(
                readings: readings,
                timeHorizon: timeHorizon,
                intervalMinutes: intervalMinutes
            )
        }
    }
    
    // MARK: - Improved Algorithm Implementation
    
    private func generateImprovedPredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int
    ) -> [PredictionPoint] {
        
        autoreleasepool {
            // Sort readings
            let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
            
            // Extract or retrieve cached features
            let features = extractFeatures(from: sortedReadings)
            
            // Generate predictions using ensemble
            var predictions: [PredictionPoint] = []
            let steps = Int(timeHorizon / Double(intervalMinutes * 60))
            
            for step in 1...steps {
                let minutesAhead = Double(step * intervalMinutes)
                let timestamp = Date().addingTimeInterval(minutesAhead * 60)
                
                // Calculate ensemble prediction
                let prediction = calculateEnsemblePrediction(
                    features: features,
                    minutesAhead: minutesAhead,
                    timestamp: timestamp
                )
                
                predictions.append(prediction)
            }
            
            // Apply smoothing to reduce noise
            return applySmoothingFilter(to: predictions)
        }
    }
    
    // MARK: - Feature Extraction
    
    private struct TimeSeriesFeatures {
        let baseValue: Double
        let trend: Double
        let acceleration: Double
        let volatility: Double
        let iob: Double
        let cob: Double
        let timeOfDay: Int // minutes since midnight
    }
    
    private func extractFeatures(from readings: [GlucoseReading]) -> TimeSeriesFeatures {
        guard let lastReading = readings.last else {
            fatalError("No readings provided")
        }
        
        // Check cache first
        if let cached = featureCache[lastReading.timestamp],
           Date().timeIntervalSince(lastReading.timestamp) < cacheValidityInterval {
            return cached
        }
        
        // Calculate features using vectorized operations where possible
        let features = autoreleasepool { () -> TimeSeriesFeatures in
            // Prepare data for Accelerate framework
            let values = readings.map { $0.calculatedValue }
            let times = readings.map { $0.timestamp.timeIntervalSince(readings[0].timestamp) / 60.0 }
            
            // Calculate trend using linear regression
            let trend = calculateTrendAccelerate(times: times, values: values)
            
            // Calculate acceleration
            let acceleration = calculateAcceleration(readings: readings)
            
            // Calculate volatility
            let volatility = calculateVolatility(values: values)
            
            // Get IOB/COB
            let (iob, cob) = calculateTreatmentEffects(at: lastReading.timestamp)
            
            // Time of day
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: lastReading.timestamp)
            let timeOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            
            return TimeSeriesFeatures(
                baseValue: lastReading.calculatedValue,
                trend: trend,
                acceleration: acceleration,
                volatility: volatility,
                iob: iob,
                cob: cob,
                timeOfDay: timeOfDay
            )
        }
        
        // Cache the features
        featureCache[lastReading.timestamp] = features
        
        // Clean old cache entries
        let cutoffDate = Date().addingTimeInterval(-300) // 5 minutes
        featureCache = featureCache.filter { $0.key > cutoffDate }
        
        return features
    }
    
    // MARK: - Accelerate Framework Operations
    
    private func calculateTrendAccelerate(times: [Double], values: [Double]) -> Double {
        guard times.count == values.count, times.count >= 2 else { return 0.0 }
        
        let n = times.count
        
        // Apply exponential weighting to give more importance to recent readings
        var weights = [Double](repeating: 0, count: n)
        let alpha = 0.5 // Decay factor - higher means more weight on recent values
        
        // Calculate weights with exponential decay
        for i in 0..<n {
            let timeFromEnd = times[n-1] - times[i]
            weights[i] = exp(-alpha * timeFromEnd / (times[n-1] - times[0]))
        }
        
        // Boost weight for the most recent readings
        if n >= 3 {
            weights[n-1] *= 2.0  // Most recent
            weights[n-2] *= 1.5  // Second most recent
        }
        
        // Normalize weights
        let totalWeight = weights.reduce(0, +)
        for i in 0..<n {
            weights[i] /= totalWeight
        }
        
        // Weighted regression
        var sumWX = 0.0
        var sumWY = 0.0
        var sumWXY = 0.0
        var sumWXX = 0.0
        var sumW = 0.0
        
        for i in 0..<n {
            let w = weights[i]
            sumW += w
            sumWX += w * times[i]
            sumWY += w * values[i]
            sumWXY += w * times[i] * values[i]
            sumWXX += w * times[i] * times[i]
        }
        
        // Calculate weighted slope
        let denominator = sumW * sumWXX - sumWX * sumWX
        guard abs(denominator) > 0.0001 else { return 0.0 }
        
        return (sumW * sumWXY - sumWX * sumWY) / denominator
    }
    
    private func calculateVolatility(values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        var differences = [Double](repeating: 0, count: values.count - 1)
        for i in 1..<values.count {
            differences[i-1] = values[i] - values[i-1]
        }
        
        var mean = 0.0
        var stdDev = 0.0
        vDSP_normalizeD(differences, 1, nil, 1, &mean, &stdDev, vDSP_Length(differences.count))
        
        return stdDev
    }
    
    // MARK: - Ensemble Prediction
    
    private struct AlgorithmWeights {
        var trend: Double = 0.4
        var momentum: Double = 0.3
        var physiological: Double = 0.3
        
        mutating func adapt(features: TimeSeriesFeatures) {
            // Adapt weights based on current conditions
            
            // Check for rapid changes by comparing recent trend to overall trend
            let rapidChange = abs(features.trend) > 2.0 || abs(features.acceleration) > 0.5
            
            if rapidChange {
                // Rapid change detected - heavily weight trend and momentum
                trend = 0.6
                momentum = 0.3
                physiological = 0.1
            } else if features.volatility < 2.0 {
                // Low volatility - trust trend more
                trend = 0.5
                momentum = 0.3
                physiological = 0.2
            } else if features.iob > 0.5 || features.cob > 5.0 {
                // Active treatments - trust physiological model more
                trend = 0.2
                momentum = 0.2
                physiological = 0.6
            } else {
                // Default weights
                trend = 0.4
                momentum = 0.3
                physiological = 0.3
            }
        }
    }
    
    private func calculateEnsemblePrediction(
        features: TimeSeriesFeatures,
        minutesAhead: Double,
        timestamp: Date
    ) -> PredictionPoint {
        
        // Adapt algorithm weights
        algorithmWeights.adapt(features: features)
        
        // Trend-based prediction with adaptive damping
        // Less damping for rapid changes, more for stable periods
        let dampingTimeConstant = abs(features.trend) > 2.0 ? 180.0 : 120.0
        let dampingFactor = exp(-minutesAhead / dampingTimeConstant)
        let trendPrediction = features.baseValue + features.trend * minutesAhead * dampingFactor
        
        // Momentum-based prediction (includes acceleration)
        let momentumPrediction = features.baseValue + 
            features.trend * minutesAhead + 
            0.5 * features.acceleration * pow(minutesAhead, 2)
        
        // Physiological prediction
        let physiologicalPrediction = calculatePhysiologicalPrediction(
            features: features,
            minutesAhead: minutesAhead,
            timestamp: timestamp
        )
        
        // Weighted ensemble
        let ensembleValue = 
            trendPrediction * algorithmWeights.trend +
            momentumPrediction * algorithmWeights.momentum +
            physiologicalPrediction * algorithmWeights.physiological
        
        // Calculate confidence based on volatility and time
        let confidence = calculateConfidence(
            volatility: features.volatility,
            minutesAhead: minutesAhead
        )
        
        return PredictionPoint(
            timestamp: timestamp,
            value: constrainGlucoseValue(ensembleValue),
            confidence: confidence,
            algorithm: "EnsembleV2"
        )
    }
    
    // MARK: - Physiological Model
    
    private func calculatePhysiologicalPrediction(
        features: TimeSeriesFeatures,
        minutesAhead: Double,
        timestamp: Date
    ) -> Double {
        
        // Get future IOB and COB
        let (futureIOB, futureCOB) = calculateTreatmentEffects(at: timestamp)
        
        // Calculate expected glucose change
        let insulinEffect = (features.iob - futureIOB) * UserDefaults.standard.insulinSensitivityMgDl
        let carbEffect = (features.cob - futureCOB) * UserDefaults.standard.insulinSensitivityMgDl / UserDefaults.standard.carbRatio
        
        // Add circadian rhythm effect
        let circadianEffect = getCircadianEffect(
            timeOfDay: features.timeOfDay + Int(minutesAhead)
        )
        
        return features.baseValue + insulinEffect + carbEffect + circadianEffect
    }
    
    private func getCircadianEffect(timeOfDay: Int) -> Double {
        let hourOfDay = (timeOfDay / 60) % 24
        
        // Simple circadian model
        switch hourOfDay {
        case 3...7:
            // Dawn phenomenon
            return Double(hourOfDay - 3) * 2.5
        case 22...23, 0...2:
            // Overnight decline
            return -5.0
        default:
            return 0.0
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateAcceleration(readings: [GlucoseReading]) -> Double {
        guard readings.count >= 3 else { return 0.0 }
        
        let recentReadings = Array(readings.suffix(5))
        guard recentReadings.count >= 3 else { return 0.0 }
        
        // Calculate rates of change
        var rates: [Double] = []
        for i in 1..<recentReadings.count {
            let timeDiff = recentReadings[i].timestamp.timeIntervalSince(
                recentReadings[i-1].timestamp
            ) / 60.0
            guard timeDiff > 0 else { continue }
            
            let rate = (recentReadings[i].calculatedValue - 
                       recentReadings[i-1].calculatedValue) / timeDiff
            rates.append(rate)
        }
        
        guard rates.count >= 2 else { return 0.0 }
        
        // Calculate acceleration as change in rate
        let rateChange = rates.last! - rates[rates.count - 2]
        return rateChange / 5.0 // Normalize by time interval
    }
    
    private func calculateTreatmentEffects(at date: Date) -> (iob: Double, cob: Double) {
        // TODO: Implement IOB/COB calculators
        // For now, return zero values to allow compilation
        // This will be replaced when treatment tracking is implemented
        return (iob: 0.0, cob: 0.0)
    }
    
    private func calculateConfidence(volatility: Double, minutesAhead: Double) -> Double {
        // Base confidence
        var confidence = 0.9
        
        // Reduce confidence with volatility
        confidence *= 1.0 / (1.0 + volatility / 5.0)
        
        // Reduce confidence with time
        confidence *= exp(-minutesAhead / 60.0)
        
        return max(0.1, min(1.0, confidence))
    }
    
    private func constrainGlucoseValue(_ value: Double) -> Double {
        return max(40, min(400, value))
    }
    
    private func applySmoothingFilter(to predictions: [PredictionPoint]) -> [PredictionPoint] {
        guard predictions.count >= 3 else { return predictions }
        
        var smoothed = predictions
        
        // Apply 3-point moving average
        for i in 1..<(predictions.count - 1) {
            let avg = (predictions[i-1].value + predictions[i].value + predictions[i+1].value) / 3.0
            smoothed[i] = PredictionPoint(
                timestamp: predictions[i].timestamp,
                value: avg,
                confidence: predictions[i].confidence,
                algorithm: predictions[i].algorithm
            )
        }
        
        return smoothed
    }
    
    // MARK: - Fallback Simple Predictions
    
    private func generateSimplePredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int
    ) -> [PredictionPoint] {
        
        // Use simple linear extrapolation for insufficient data
        guard readings.count >= 2 else { return [] }
        
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        let recent = Array(sortedReadings.suffix(3))
        
        // Calculate simple trend
        let timeDiff = recent.last!.timestamp.timeIntervalSince(recent.first!.timestamp) / 60.0
        guard timeDiff > 0 else { return [] }
        
        let valueDiff = recent.last!.calculatedValue - recent.first!.calculatedValue
        let trend = valueDiff / timeDiff
        
        // Generate predictions
        var predictions: [PredictionPoint] = []
        let steps = Int(timeHorizon / Double(intervalMinutes * 60))
        
        for step in 1...steps {
            let minutesAhead = Double(step * intervalMinutes)
            let value = recent.last!.calculatedValue + trend * minutesAhead
            
            predictions.append(PredictionPoint(
                timestamp: Date().addingTimeInterval(minutesAhead * 60),
                value: constrainGlucoseValue(value),
                confidence: 0.5,
                algorithm: "SimpleTrend"
            ))
        }
        
        return predictions
    }
}

// MARK: - PredictionManagerProtocol Conformance

extension PredictionManagerV2: PredictionManagerProtocol {
    func predictLowGlucose(
        readings: [GlucoseReading],
        threshold: Double,
        maxHoursAhead: Double
    ) -> (timeToLow: TimeInterval, severity: LowPredictionSeverity)? {
        // For now, use the simple implementation
        // Could be enhanced with the improved algorithm
        let predictions = generatePredictions(
            readings: readings,
            timeHorizon: maxHoursAhead * 3600,
            intervalMinutes: 5
        )
        
        for prediction in predictions {
            if prediction.value < threshold {
                let timeToLow = prediction.timestamp.timeIntervalSinceNow
                let severity: LowPredictionSeverity = prediction.value < (threshold - 20) ? .urgent : .moderate
                return (timeToLow, severity)
            }
        }
        
        return nil
    }
}