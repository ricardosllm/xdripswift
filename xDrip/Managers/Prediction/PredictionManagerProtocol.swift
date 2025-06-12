import Foundation

/// Protocol defining the interface for prediction managers
protocol PredictionManagerProtocol {
    /// Generates glucose predictions
    func generatePredictions(
        readings: [GlucoseReading],
        timeHorizon: TimeInterval,
        intervalMinutes: Int
    ) -> [PredictionPoint]
    
    /// Predicts if glucose will go low
    func predictLowGlucose(
        readings: [GlucoseReading],
        threshold: Double,
        maxHoursAhead: Double
    ) -> (timeToLow: TimeInterval, severity: LowPredictionSeverity)?
}

/// Make existing PredictionManager conform to the protocol
extension PredictionManager: PredictionManagerProtocol {}

/// Make PredictionManagerV2 conform to the protocol
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