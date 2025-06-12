import Foundation
import Accelerate
import os.log

/// Improved glucose prediction manager using advanced algorithms and physiological models
/// Based on research showing LSTM networks and absorption curves provide best accuracy
public class ImprovedPredictionManager {
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let log = OSLog(subsystem: "PredictionManager", category: "Improved")
    
    // Physiological parameters (can be personalized)
    private var insulinSensitivityFactor: Double = 40.0 // mg/dL per unit
    private var carbRatio: Double = 10.0 // grams per unit
    private var basalRate: Double = 1.0 // units per hour
    
    // Model parameters
    private let minimumReadingsRequired = 12 // 1 hour of data minimum
    private let optimalReadingsCount = 48 // 4 hours preferred
    private let maxLookbackHours = 12.0
    
    // Time series analysis windows
    private let shortTermWindow = 30 // minutes
    private let mediumTermWindow = 120 // minutes
    private let longTermWindow = 360 // minutes
    
    // MARK: - Initialization
    
    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        loadPersonalizedParameters()
    }
    
    // MARK: - Main Prediction Method
    
    /// Generates advanced glucose predictions using multiple models and physiological understanding
    public func generateImprovedPredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int = 5
    ) -> [PredictionPoint] {
        
        // Validate input
        guard readings.count >= minimumReadingsRequired else {
            os_log("Insufficient readings: %{public}d", log: log, type: .info, readings.count)
            return []
        }
        
        // Sort readings by timestamp
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        
        // Extract features from time series
        let features = extractTimeSeriesFeatures(from: sortedReadings)
        
        // Get treatment effects
        let treatmentEffects = calculateTreatmentEffects(at: Date(), horizon: timeHorizon)
        
        // Generate base predictions using multiple models
        let trendPrediction = generateTrendBasedPrediction(
            readings: sortedReadings,
            features: features,
            horizon: timeHorizon,
            interval: intervalMinutes
        )
        
        let patternPrediction = generatePatternBasedPrediction(
            readings: sortedReadings,
            features: features,
            horizon: timeHorizon,
            interval: intervalMinutes
        )
        
        let physiologicalPrediction = generatePhysiologicalPrediction(
            readings: sortedReadings,
            treatmentEffects: treatmentEffects,
            horizon: timeHorizon,
            interval: intervalMinutes
        )
        
        // Combine predictions using weighted ensemble
        let combinedPrediction = combinePredictons(
            trend: trendPrediction,
            pattern: patternPrediction,
            physiological: physiologicalPrediction,
            features: features
        )
        
        // Apply safety constraints and smoothing
        let finalPrediction = applySafetyConstraints(to: combinedPrediction)
        
        return finalPrediction
    }
    
    // MARK: - Feature Extraction
    
    private struct TimeSeriesFeatures {
        let currentValue: Double
        let shortTermTrend: Double // mg/dL per minute
        let mediumTermTrend: Double
        let longTermTrend: Double
        let volatility: Double
        let acceleration: Double
        let timeOfDay: Double // 0-24 hours
        let minutesSinceLastMeal: Double?
        let minutesSinceLastInsulin: Double?
        let activeIOB: Double
        let activeCOB: Double
        let patternStrength: Double // How well current pattern matches historical
    }
    
    private func extractTimeSeriesFeatures(from readings: [GlucoseReading]) -> TimeSeriesFeatures {
        guard let lastReading = readings.last else {
            fatalError("No readings provided")
        }
        
        let now = lastReading.timestamp
        
        // Calculate trends at different time scales using weighted regression
        let shortTermTrend = calculateWeightedTrend(
            readings: readings,
            windowMinutes: shortTermWindow,
            endTime: now
        )
        
        let mediumTermTrend = calculateWeightedTrend(
            readings: readings,
            windowMinutes: mediumTermWindow,
            endTime: now
        )
        
        let longTermTrend = calculateWeightedTrend(
            readings: readings,
            windowMinutes: longTermWindow,
            endTime: now
        )
        
        // Calculate volatility (standard deviation of rate of change)
        let volatility = calculateVolatility(readings: readings, windowMinutes: 60)
        
        // Calculate acceleration (second derivative)
        let acceleration = calculateAcceleration(readings: readings)
        
        // Time of day feature (important for dawn phenomenon, etc.)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeOfDay = Double(hour) + Double(minute) / 60.0
        
        // Get treatment timing
        let treatments = fetchRecentTreatments(before: now, hours: 6)
        let minutesSinceLastMeal = treatments.lastMeal.map { now.timeIntervalSince($0) / 60.0 }
        let minutesSinceLastInsulin = treatments.lastInsulin.map { now.timeIntervalSince($0) / 60.0 }
        
        // Calculate IOB and COB
        let iobCalculator = IOBCalculator(coreDataManager: coreDataManager)
        let cobCalculator = COBCalculator(coreDataManager: coreDataManager)
        
        let iobValue = iobCalculator.calculateIOB(
            at: now,
            insulinType: UserDefaults.standard.insulinType,
            insulinSensitivity: insulinSensitivityFactor
        )
        
        let cobValue = cobCalculator.calculateCOB(
            at: now,
            absorptionRate: UserDefaults.standard.carbAbsorptionRate,
            delay: UserDefaults.standard.carbAbsorptionDelay,
            carbRatio: carbRatio,
            insulinSensitivity: insulinSensitivityFactor
        )
        
        // Calculate pattern matching strength
        let patternStrength = calculatePatternMatchingStrength(
            currentReadings: readings,
            timeOfDay: timeOfDay
        )
        
        return TimeSeriesFeatures(
            currentValue: lastReading.calculatedValue,
            shortTermTrend: shortTermTrend,
            mediumTermTrend: mediumTermTrend,
            longTermTrend: longTermTrend,
            volatility: volatility,
            acceleration: acceleration,
            timeOfDay: timeOfDay,
            minutesSinceLastMeal: minutesSinceLastMeal,
            minutesSinceLastInsulin: minutesSinceLastInsulin,
            activeIOB: iobValue.iob,
            activeCOB: cobValue.cob,
            patternStrength: patternStrength
        )
    }
    
    // MARK: - Trend-Based Prediction (Enhanced Regression)
    
    private func generateTrendBasedPrediction(
        readings: [GlucoseReading],
        features: TimeSeriesFeatures,
        horizon: TimeInterval,
        interval: Int
    ) -> [PredictionPoint] {
        
        var predictions: [PredictionPoint] = []
        let steps = Int(horizon / Double(interval * 60))
        
        // Use adaptive trend based on volatility and time scales
        let adaptiveTrend = calculateAdaptiveTrend(features: features)
        
        // Apply non-linear damping to trend over time
        for step in 1...steps {
            let minutesAhead = Double(step * interval)
            let dampingFactor = calculateTrendDamping(
                minutesAhead: minutesAhead,
                volatility: features.volatility
            )
            
            let trendComponent = adaptiveTrend * minutesAhead * dampingFactor
            let predictedValue = features.currentValue + trendComponent
            
            let timestamp = Date().addingTimeInterval(minutesAhead * 60)
            predictions.append(PredictionPoint(
                timestamp: timestamp,
                value: predictedValue,
                confidence: 0.8 * dampingFactor,
                algorithm: "AdaptiveTrend"
            ))
        }
        
        return predictions
    }
    
    // MARK: - Pattern-Based Prediction (Time Series Patterns)
    
    private func generatePatternBasedPrediction(
        readings: [GlucoseReading],
        features: TimeSeriesFeatures,
        horizon: TimeInterval,
        interval: Int
    ) -> [PredictionPoint] {
        
        var predictions: [PredictionPoint] = []
        let steps = Int(horizon / Double(interval * 60))
        
        // Find similar historical patterns
        let historicalPatterns = findSimilarHistoricalPatterns(
            currentFeatures: features,
            lookbackDays: 7
        )
        
        guard !historicalPatterns.isEmpty else {
            // Fallback to simple pattern
            return generateSimplePatternPrediction(
                features: features,
                horizon: horizon,
                interval: interval
            )
        }
        
        // Average the outcomes of similar patterns
        for step in 1...steps {
            let minutesAhead = Double(step * interval)
            var predictedValues: [Double] = []
            var weights: [Double] = []
            
            for pattern in historicalPatterns {
                if let futureValue = pattern.getValueAt(minutesAfter: minutesAhead) {
                    predictedValues.append(futureValue)
                    weights.append(pattern.similarity)
                }
            }
            
            guard !predictedValues.isEmpty else { continue }
            
            // Weighted average of pattern outcomes
            let weightedSum = zip(predictedValues, weights).reduce(0.0) { $0 + $1.0 * $1.1 }
            let totalWeight = weights.reduce(0.0, +)
            let predictedValue = weightedSum / totalWeight
            
            let timestamp = Date().addingTimeInterval(minutesAhead * 60)
            predictions.append(PredictionPoint(
                timestamp: timestamp,
                value: predictedValue,
                confidence: min(0.9, totalWeight / Double(historicalPatterns.count)),
                algorithm: "PatternMatching"
            ))
        }
        
        return predictions
    }
    
    // MARK: - Physiological Model Prediction
    
    private func generatePhysiologicalPrediction(
        readings: [GlucoseReading],
        treatmentEffects: TreatmentEffects,
        horizon: TimeInterval,
        interval: Int
    ) -> [PredictionPoint] {
        
        var predictions: [PredictionPoint] = []
        let steps = Int(horizon / Double(interval * 60))
        
        guard let lastReading = readings.last else { return [] }
        let baseGlucose = lastReading.calculatedValue
        
        // Model glucose dynamics with treatment effects
        for step in 1...steps {
            let minutesAhead = Double(step * interval)
            let timepoint = Date().addingTimeInterval(minutesAhead * 60)
            
            // Calculate treatment effects at this timepoint
            let insulinEffect = treatmentEffects.getInsulinEffectAt(time: timepoint)
            let carbEffect = treatmentEffects.getCarbEffectAt(time: timepoint)
            
            // Apply first-order glucose dynamics model
            let glucoseChange = (carbEffect - insulinEffect) * (minutesAhead / 60.0)
            
            // Add basal rate effect
            let basalEffect = basalRate * insulinSensitivityFactor * (minutesAhead / 60.0)
            
            // Consider glucose-dependent clearance (physiological feedback)
            let clearanceRate = calculateGlucoseClearanceRate(glucose: baseGlucose + glucoseChange)
            let clearanceEffect = clearanceRate * minutesAhead
            
            let predictedValue = baseGlucose + glucoseChange - basalEffect - clearanceEffect
            
            predictions.append(PredictionPoint(
                timestamp: timepoint,
                value: max(40, predictedValue), // Physiological floor
                confidence: treatmentEffects.confidence,
                algorithm: "Physiological"
            ))
        }
        
        return predictions
    }
    
    // MARK: - Ensemble Combination
    
    private func combinePredictons(
        trend: [PredictionPoint],
        pattern: [PredictionPoint],
        physiological: [PredictionPoint],
        features: TimeSeriesFeatures
    ) -> [PredictionPoint] {
        
        var combined: [PredictionPoint] = []
        
        // Calculate adaptive weights based on current conditions
        let weights = calculateEnsembleWeights(features: features)
        
        // Combine predictions at each timepoint
        let allTimestamps = Set(trend.map { $0.timestamp } + 
                               pattern.map { $0.timestamp } + 
                               physiological.map { $0.timestamp }).sorted()
        
        for timestamp in allTimestamps {
            var weightedSum = 0.0
            var totalWeight = 0.0
            var algorithmContributions: [String: Double] = [:]
            
            // Trend contribution
            if let trendPoint = trend.first(where: { $0.timestamp == timestamp }) {
                let weight = weights.trend * trendPoint.confidence
                weightedSum += trendPoint.value * weight
                totalWeight += weight
                algorithmContributions["Trend"] = weight
            }
            
            // Pattern contribution
            if let patternPoint = pattern.first(where: { $0.timestamp == timestamp }) {
                let weight = weights.pattern * patternPoint.confidence
                weightedSum += patternPoint.value * weight
                totalWeight += weight
                algorithmContributions["Pattern"] = weight
            }
            
            // Physiological contribution
            if let physPoint = physiological.first(where: { $0.timestamp == timestamp }) {
                let weight = weights.physiological * physPoint.confidence
                weightedSum += physPoint.value * weight
                totalWeight += weight
                algorithmContributions["Physiological"] = weight
            }
            
            guard totalWeight > 0 else { continue }
            
            let combinedValue = weightedSum / totalWeight
            let combinedConfidence = totalWeight / (weights.trend + weights.pattern + weights.physiological)
            
            // Determine primary algorithm
            let primaryAlgorithm = algorithmContributions.max(by: { $0.value < $1.value })?.key ?? "Ensemble"
            
            combined.append(PredictionPoint(
                timestamp: timestamp,
                value: combinedValue,
                confidence: combinedConfidence,
                algorithm: primaryAlgorithm
            ))
        }
        
        return combined
    }
    
    // MARK: - Helper Methods
    
    private func calculateWeightedTrend(
        readings: [GlucoseReading],
        windowMinutes: Int,
        endTime: Date
    ) -> Double {
        
        let windowStart = endTime.addingTimeInterval(-Double(windowMinutes * 60))
        let windowReadings = readings.filter { $0.timestamp >= windowStart }
        
        guard windowReadings.count >= 2 else { return 0.0 }
        
        // Use exponential weighting - more recent readings have higher weight
        let alpha = 0.3 // Decay factor
        var weightedSumX = 0.0
        var weightedSumY = 0.0
        var weightedSumXY = 0.0
        var weightedSumX2 = 0.0
        var totalWeight = 0.0
        
        for reading in windowReadings {
            let minutesFromEnd = endTime.timeIntervalSince(reading.timestamp) / 60.0
            let weight = exp(-alpha * minutesFromEnd / Double(windowMinutes))
            
            weightedSumX += minutesFromEnd * weight
            weightedSumY += reading.calculatedValue * weight
            weightedSumXY += minutesFromEnd * reading.calculatedValue * weight
            weightedSumX2 += minutesFromEnd * minutesFromEnd * weight
            totalWeight += weight
        }
        
        // Calculate weighted linear regression slope
        let denominator = totalWeight * weightedSumX2 - weightedSumX * weightedSumX
        guard abs(denominator) > 0.0001 else { return 0.0 }
        
        let slope = (totalWeight * weightedSumXY - weightedSumX * weightedSumY) / denominator
        
        return -slope // Negative because we measure minutes from end
    }
    
    private func calculateVolatility(readings: [GlucoseReading], windowMinutes: Int) -> Double {
        let windowStart = Date().addingTimeInterval(-Double(windowMinutes * 60))
        let windowReadings = readings.filter { $0.timestamp >= windowStart }
        
        guard windowReadings.count >= 3 else { return 0.0 }
        
        var rateChanges: [Double] = []
        for i in 1..<windowReadings.count {
            let timeDiff = windowReadings[i].timestamp.timeIntervalSince(windowReadings[i-1].timestamp) / 60.0
            guard timeDiff > 0 else { continue }
            let rateChange = (windowReadings[i].calculatedValue - windowReadings[i-1].calculatedValue) / timeDiff
            rateChanges.append(rateChange)
        }
        
        guard !rateChanges.isEmpty else { return 0.0 }
        
        let mean = rateChanges.reduce(0.0, +) / Double(rateChanges.count)
        let variance = rateChanges.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(rateChanges.count)
        
        return sqrt(variance)
    }
    
    private func calculateAcceleration(readings: [GlucoseReading]) -> Double {
        guard readings.count >= 3 else { return 0.0 }
        
        let recentReadings = Array(readings.suffix(5))
        guard recentReadings.count >= 3 else { return 0.0 }
        
        // Calculate first derivatives (velocities)
        var velocities: [(time: Double, velocity: Double)] = []
        for i in 1..<recentReadings.count {
            let timeDiff = recentReadings[i].timestamp.timeIntervalSince(recentReadings[i-1].timestamp) / 60.0
            guard timeDiff > 0 else { continue }
            let velocity = (recentReadings[i].calculatedValue - recentReadings[i-1].calculatedValue) / timeDiff
            let midTime = recentReadings[i-1].timestamp.addingTimeInterval(timeDiff * 30).timeIntervalSince1970
            velocities.append((time: midTime, velocity: velocity))
        }
        
        guard velocities.count >= 2 else { return 0.0 }
        
        // Calculate second derivative (acceleration)
        let lastIndex = velocities.count - 1
        let timeDiff = (velocities[lastIndex].time - velocities[lastIndex-1].time) / 60.0
        guard timeDiff > 0 else { return 0.0 }
        
        return (velocities[lastIndex].velocity - velocities[lastIndex-1].velocity) / timeDiff
    }
    
    private func calculateAdaptiveTrend(features: TimeSeriesFeatures) -> Double {
        // Weight different time scales based on volatility and consistency
        let shortWeight = 0.5 * (1.0 - min(features.volatility / 5.0, 1.0))
        let mediumWeight = 0.3
        let longWeight = 0.2 * features.patternStrength
        
        let totalWeight = shortWeight + mediumWeight + longWeight
        
        return (features.shortTermTrend * shortWeight +
                features.mediumTermTrend * mediumWeight +
                features.longTermTrend * longWeight) / totalWeight
    }
    
    private func calculateTrendDamping(minutesAhead: Double, volatility: Double) -> Double {
        // More aggressive damping for volatile glucose and longer predictions
        let timeDamping = exp(-minutesAhead / (120.0 - min(volatility * 10, 60)))
        let volatilityDamping = 1.0 / (1.0 + volatility / 3.0)
        
        return timeDamping * volatilityDamping
    }
    
    private func calculateGlucoseClearanceRate(glucose: Double) -> Double {
        // Michaelis-Menten kinetics for glucose clearance
        let vMax = 2.0 // mg/dL/min maximum clearance rate
        let km = 180.0 // mg/dL half-saturation constant
        
        return vMax * glucose / (km + glucose)
    }
    
    private func applySafetyConstraints(to predictions: [PredictionPoint]) -> [PredictionPoint] {
        return predictions.map { point in
            // Apply physiological constraints
            let constrainedValue = min(max(point.value, 40), 400)
            
            // Reduce confidence for extreme predictions
            var adjustedConfidence = point.confidence
            if constrainedValue < 70 || constrainedValue > 250 {
                adjustedConfidence *= 0.8
            }
            
            return PredictionPoint(
                timestamp: point.timestamp,
                value: constrainedValue,
                confidence: adjustedConfidence,
                algorithm: point.algorithm
            )
        }
    }
    
    // MARK: - Pattern Matching
    
    private struct HistoricalPattern {
        let startTime: Date
        let readings: [GlucoseReading]
        let similarity: Double
        
        func getValueAt(minutesAfter: Double) -> Double? {
            let targetTime = startTime.addingTimeInterval(minutesAfter * 60)
            
            // Find closest reading
            var closestReading: GlucoseReading?
            var minTimeDiff = Double.infinity
            
            for reading in readings {
                let timeDiff = abs(reading.timestamp.timeIntervalSince(targetTime))
                if timeDiff < minTimeDiff && timeDiff < 300 { // Within 5 minutes
                    closestReading = reading
                    minTimeDiff = timeDiff
                }
            }
            
            return closestReading?.calculatedValue
        }
    }
    
    private func findSimilarHistoricalPatterns(
        currentFeatures: TimeSeriesFeatures,
        lookbackDays: Int
    ) -> [HistoricalPattern] {
        
        // This is a simplified implementation
        // In a real app, you would search historical data for similar patterns
        return []
    }
    
    private func calculatePatternMatchingStrength(
        currentReadings: [GlucoseReading],
        timeOfDay: Double
    ) -> Double {
        // Simplified - would compare to historical patterns at similar time of day
        return 0.7
    }
    
    // MARK: - Treatment Effects
    
    private struct TreatmentEffects {
        let insulinCurve: [(time: Date, effect: Double)]
        let carbCurve: [(time: Date, effect: Double)]
        let confidence: Double
        
        func getInsulinEffectAt(time: Date) -> Double {
            // Interpolate from curve
            var totalEffect = 0.0
            for i in 1..<insulinCurve.count {
                if time >= insulinCurve[i-1].time && time <= insulinCurve[i].time {
                    let fraction = time.timeIntervalSince(insulinCurve[i-1].time) /
                                  insulinCurve[i].time.timeIntervalSince(insulinCurve[i-1].time)
                    totalEffect = insulinCurve[i-1].effect + 
                                 (insulinCurve[i].effect - insulinCurve[i-1].effect) * fraction
                    break
                }
            }
            return totalEffect
        }
        
        func getCarbEffectAt(time: Date) -> Double {
            // Similar interpolation for carbs
            var totalEffect = 0.0
            for i in 1..<carbCurve.count {
                if time >= carbCurve[i-1].time && time <= carbCurve[i].time {
                    let fraction = time.timeIntervalSince(carbCurve[i-1].time) /
                                  carbCurve[i].time.timeIntervalSince(carbCurve[i-1].time)
                    totalEffect = carbCurve[i-1].effect + 
                                 (carbCurve[i].effect - carbCurve[i-1].effect) * fraction
                    break
                }
            }
            return totalEffect
        }
    }
    
    private func calculateTreatmentEffects(at startTime: Date, horizon: TimeInterval) -> TreatmentEffects {
        let iobCalculator = IOBCalculator(coreDataManager: coreDataManager)
        let cobCalculator = COBCalculator(coreDataManager: coreDataManager)
        
        var insulinCurve: [(time: Date, effect: Double)] = []
        var carbCurve: [(time: Date, effect: Double)] = []
        
        // Calculate effects at 5-minute intervals
        for minutes in stride(from: 0, through: Int(horizon / 60), by: 5) {
            let time = startTime.addingTimeInterval(Double(minutes * 60))
            
            let iob = iobCalculator.calculateIOB(
                at: time,
                insulinType: UserDefaults.standard.insulinType,
                insulinSensitivity: insulinSensitivityFactor
            )
            
            let cob = cobCalculator.calculateCOB(
                at: time,
                absorptionRate: UserDefaults.standard.carbAbsorptionRate,
                delay: UserDefaults.standard.carbAbsorptionDelay,
                carbRatio: carbRatio,
                insulinSensitivity: insulinSensitivityFactor
            )
            
            insulinCurve.append((time: time, effect: iob.rate * insulinSensitivityFactor))
            carbCurve.append((time: time, effect: cob.rate))
        }
        
        let confidence = min(insulinCurve.count, carbCurve.count) > 0 ? 0.8 : 0.3
        
        return TreatmentEffects(
            insulinCurve: insulinCurve,
            carbCurve: carbCurve,
            confidence: confidence
        )
    }
    
    private func fetchRecentTreatments(before: Date, hours: Double) -> (lastMeal: Date?, lastInsulin: Date?) {
        // Simplified - would fetch from Core Data
        return (nil, nil)
    }
    
    // MARK: - Ensemble Weights
    
    private struct EnsembleWeights {
        let trend: Double
        let pattern: Double
        let physiological: Double
    }
    
    private func calculateEnsembleWeights(features: TimeSeriesFeatures) -> EnsembleWeights {
        // Adaptive weights based on current conditions
        
        var trendWeight = 0.4
        var patternWeight = 0.3
        var physiologicalWeight = 0.3
        
        // Increase trend weight if low volatility
        if features.volatility < 1.0 {
            trendWeight += 0.1
            patternWeight -= 0.05
            physiologicalWeight -= 0.05
        }
        
        // Increase physiological weight if recent treatments
        if features.activeIOB > 0.1 || features.activeCOB > 0.1 {
            physiologicalWeight += 0.2
            trendWeight -= 0.1
            patternWeight -= 0.1
        }
        
        // Increase pattern weight if strong pattern match
        if features.patternStrength > 0.8 {
            patternWeight += 0.15
            trendWeight -= 0.075
            physiologicalWeight -= 0.075
        }
        
        // Normalize weights
        let total = trendWeight + patternWeight + physiologicalWeight
        
        return EnsembleWeights(
            trend: trendWeight / total,
            pattern: patternWeight / total,
            physiological: physiologicalWeight / total
        )
    }
    
    // MARK: - Personalization
    
    private func loadPersonalizedParameters() {
        // Load from UserDefaults
        insulinSensitivityFactor = UserDefaults.standard.insulinSensitivityMgDl
        carbRatio = UserDefaults.standard.carbRatio
        
        // Could also load learned parameters from Core Data
        // This would include personal patterns, typical responses, etc.
    }
    
    private func generateSimplePatternPrediction(
        features: TimeSeriesFeatures,
        horizon: TimeInterval,
        interval: Int
    ) -> [PredictionPoint] {
        // Fallback pattern prediction using time of day patterns
        var predictions: [PredictionPoint] = []
        let steps = Int(horizon / Double(interval * 60))
        
        for step in 1...steps {
            let minutesAhead = Double(step * interval)
            let futureTimeOfDay = features.timeOfDay + minutesAhead / 60.0
            
            // Simple circadian rhythm pattern
            let circadianEffect = getCircadianEffect(timeOfDay: futureTimeOfDay.truncatingRemainder(dividingBy: 24))
            let predictedValue = features.currentValue + circadianEffect * minutesAhead / 60.0
            
            predictions.append(PredictionPoint(
                timestamp: Date().addingTimeInterval(minutesAhead * 60),
                value: predictedValue,
                confidence: 0.5,
                algorithm: "SimplePattern"
            ))
        }
        
        return predictions
    }
    
    private func getCircadianEffect(timeOfDay: Double) -> Double {
        // Simplified circadian pattern
        if timeOfDay >= 3 && timeOfDay <= 8 {
            // Dawn phenomenon
            return 10.0
        } else if timeOfDay >= 22 || timeOfDay <= 2 {
            // Overnight drop
            return -5.0
        } else {
            return 0.0
        }
    }
}