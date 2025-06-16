import Foundation
import os.log

/// Cache for MDI predictions to reduce recalculation frequency
class MDIPredictionCache {
    
    // MARK: - Properties
    
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "MDIPredictionCache")
    
    /// Cached prediction result
    private var cachedPrediction: CachedPrediction?
    
    /// Cache validity duration (5 minutes)
    private let cacheValidityDuration: TimeInterval = 300
    
    /// Minimum BG change to invalidate cache (10 mg/dL)
    private let significantBGChange: Double = 10.0
    
    /// Structure to hold cached prediction data
    private struct CachedPrediction {
        let prediction: iAPSPredictionManager.PredictionResult
        let timestamp: Date
        let basedOnBG: Double
        let basedOnIOB: Double
        let basedOnCOB: Double
        let treatmentCount: Int
        
        /// Check if cache is still valid
        func isValid(currentBG: Double, currentIOB: Double, currentCOB: Double, currentTreatmentCount: Int) -> Bool {
            // Check age
            let age = -timestamp.timeIntervalSinceNow
            guard age < 300 else { // 5 minutes
                return false
            }
            
            // Check if BG has changed significantly
            if abs(currentBG - basedOnBG) > 10.0 {
                return false
            }
            
            // Check if IOB has changed significantly (more than 0.5U)
            if abs(currentIOB - basedOnIOB) > 0.5 {
                return false
            }
            
            // Check if COB has changed significantly (more than 5g)
            if abs(currentCOB - basedOnCOB) > 5.0 {
                return false
            }
            
            // Check if new treatments were added
            if currentTreatmentCount != treatmentCount {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Public Methods
    
    /// Get cached prediction if valid, otherwise nil
    func getCachedPrediction(
        currentBG: Double,
        currentIOB: Double,
        currentCOB: Double,
        treatmentCount: Int
    ) -> iAPSPredictionManager.PredictionResult? {
        
        guard let cached = cachedPrediction else {
            os_log("No cached prediction available", log: log, type: .debug)
            return nil
        }
        
        if cached.isValid(
            currentBG: currentBG,
            currentIOB: currentIOB,
            currentCOB: currentCOB,
            currentTreatmentCount: treatmentCount
        ) {
            let cacheAge = -cached.timestamp.timeIntervalSinceNow
            os_log("Using cached prediction (age: %.1f seconds)", log: log, type: .info, cacheAge)
            return cached.prediction
        } else {
            os_log("Cached prediction invalid", log: log, type: .debug)
            cachedPrediction = nil
            return nil
        }
    }
    
    /// Store a new prediction in cache
    func cachePrediction(
        _ prediction: iAPSPredictionManager.PredictionResult,
        basedOnBG: Double,
        basedOnIOB: Double,
        basedOnCOB: Double,
        treatmentCount: Int
    ) {
        cachedPrediction = CachedPrediction(
            prediction: prediction,
            timestamp: Date(),
            basedOnBG: basedOnBG,
            basedOnIOB: basedOnIOB,
            basedOnCOB: basedOnCOB,
            treatmentCount: treatmentCount
        )
        
        os_log("Cached new prediction", log: log, type: .info)
    }
    
    /// Clear the cache
    func clearCache() {
        cachedPrediction = nil
        os_log("Cleared prediction cache", log: log, type: .info)
    }
    
    /// Get cache status for debugging
    func getCacheStatus() -> String {
        guard let cached = cachedPrediction else {
            return "No cached prediction"
        }
        
        let age = -cached.timestamp.timeIntervalSinceNow
        return String(format: "Cached prediction: age=%.1fs, BG=%.0f, IOB=%.1f, COB=%.0f",
                     age, cached.basedOnBG, cached.basedOnIOB, cached.basedOnCOB)
    }
}