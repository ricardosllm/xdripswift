import Foundation
import os.log

/// Advanced bolus calculator for MDI Loop recommendations
/// Uses IOB, COB, and prediction data for accurate dose calculations
final class MDIBolusCalculator {
    
    // MARK: - Properties
    
    /// Log for calculator operations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// IOB Calculator instance
    private var iobCalculator: IOBCalculator?
    
    /// COB Calculator instance  
    private var cobCalculator: COBCalculator?
    
    /// Core Data Manager
    private weak var coreDataManager: CoreDataManager?
    
    /// Treatment entry accessor
    private var treatmentEntryAccessor: TreatmentEntryAccessor?
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        self.iobCalculator = IOBCalculator(coreDataManager: coreDataManager)
        self.cobCalculator = COBCalculator(coreDataManager: coreDataManager)
    }
    
    // MARK: - Public Methods
    
    /// Calculate comprehensive bolus recommendation
    /// - Parameters:
    ///   - currentGlucose: Current glucose value in mg/dL
    ///   - targetGlucose: Target glucose value in mg/dL
    ///   - recentReadings: Recent glucose readings for trend analysis
    ///   - mealCarbs: Carbs for upcoming meal (if any)
    /// - Returns: Detailed bolus recommendation
    func calculateBolusRecommendation(
        currentGlucose: Double,
        targetGlucose: Double,
        recentReadings: [BgReading],
        mealCarbs: Double? = nil
    ) -> DetailedBolusRecommendation {
        
        // Get user settings
        let isf = UserDefaults.standard.insulinSensitivityMgDl // Insulin Sensitivity Factor
        let carbRatio = UserDefaults.standard.carbRatio // Carb Ratio (g/U)
        let insulinType = InsulinType.fromString(UserDefaults.standard.insulinType) ?? .rapid
        
        // Calculate current IOB
        let currentIOB = iobCalculator?.calculateIOB(
            at: Date(),
            insulinType: insulinType,
            insulinSensitivity: isf
        ) ?? IOBValue(iob: 0, glucoseDrop: 0, timestamp: Date())
        
        // Calculate current COB
        let currentCOB = cobCalculator?.calculateCOB(
            at: Date(),
            absorptionRate: UserDefaults.standard.carbAbsorptionRate,
            delay: UserDefaults.standard.carbAbsorptionDelay,
            carbRatio: carbRatio,
            insulinSensitivity: isf
        ) ?? COBValue(cob: 0, glucoseRise: 0, timestamp: Date())
        
        // Calculate glucose trend
        let trend = calculateTrend(from: recentReadings)
        let projectedGlucose = projectGlucose(
            current: currentGlucose,
            trend: trend,
            iobDrop: currentIOB.glucoseDrop,
            cobRise: currentCOB.glucoseRise,
            minutes: 30
        )
        
        // Calculate correction needed
        let glucoseCorrection = (projectedGlucose - targetGlucose) / isf
        
        // Calculate meal bolus if carbs provided
        let mealBolus = (mealCarbs ?? 0) / carbRatio
        
        // Calculate net insulin needed
        let totalInsulinNeeded = glucoseCorrection + mealBolus
        let netInsulinNeeded = totalInsulinNeeded - currentIOB.iob
        
        // Apply safety limits
        let recommendedDose = max(0, netInsulinNeeded)
        
        // Round to nearest 0.5 units
        let roundedDose = round(recommendedDose * 2) / 2
        
        // Create detailed recommendation
        return DetailedBolusRecommendation(
            totalDose: roundedDose,
            correctionComponent: glucoseCorrection,
            mealComponent: mealBolus,
            iobSubtracted: currentIOB.iob,
            currentIOB: currentIOB.iob,
            currentCOB: currentCOB.cob,
            projectedGlucose: projectedGlucose,
            currentGlucose: currentGlucose,
            targetGlucose: targetGlucose,
            trend: trend,
            confidence: calculateConfidence(recentReadings: recentReadings),
            reasoning: generateReasoning(
                correction: glucoseCorrection,
                meal: mealBolus,
                iob: currentIOB.iob,
                projected: projectedGlucose,
                target: targetGlucose
            )
        )
    }
    
    /// Calculate simple correction dose (legacy method for compatibility)
    func calculateSimpleCorrectionDose(glucose: Double, target: Double, isf: Double) -> Double {
        let correction = (glucose - target) / isf
        return max(0, round(correction * 2) / 2)
    }
    
    // MARK: - Private Methods
    
    /// Project future glucose based on current value, trend, IOB, and COB
    private func projectGlucose(
        current: Double,
        trend: Double,
        iobDrop: Double,
        cobRise: Double,
        minutes: Double
    ) -> Double {
        // Simple linear projection with IOB/COB effects
        let trendEffect = trend * minutes
        let netEffect = cobRise - iobDrop
        return current + trendEffect + netEffect
    }
    
    /// Calculate trend from recent readings
    private func calculateTrend(from readings: [BgReading]) -> Double {
        guard readings.count >= 3 else { return 0 }
        
        let sortedReadings = readings.sorted { $0.timeStamp < $1.timeStamp }
        guard let first = sortedReadings.first,
              let last = sortedReadings.last else { return 0 }
        
        let timeDiff = last.timeStamp.timeIntervalSince(first.timeStamp) / 60
        guard timeDiff > 0 else { return 0 }
        
        let glucoseDiff = last.calculatedValue - first.calculatedValue
        return glucoseDiff / timeDiff
    }
    
    /// Calculate confidence level based on data quality
    private func calculateConfidence(recentReadings: [BgReading]) -> Double {
        var confidence = 1.0
        
        // Reduce confidence if not enough readings
        if recentReadings.count < 5 {
            confidence *= 0.8
        }
        
        // Reduce confidence if readings are old
        if let latest = recentReadings.last {
            let minutesOld = Date().timeIntervalSince(latest.timeStamp) / 60
            if minutesOld > 10 {
                confidence *= 0.7
            }
        }
        
        // Could add more factors: sensor noise, calibration recency, etc.
        
        return confidence
    }
    
    /// Generate human-readable reasoning for the recommendation
    private func generateReasoning(
        correction: Double,
        meal: Double,
        iob: Double,
        projected: Double,
        target: Double
    ) -> String {
        var parts: [String] = []
        
        if correction > 0 {
            parts.append("Correction needed: \(String(format: "%.1f", correction))U")
        } else if correction < 0 {
            parts.append("Below target by \(Int(target - projected)) mg/dL")
        }
        
        if meal > 0 {
            parts.append("Meal bolus: \(String(format: "%.1f", meal))U")
        }
        
        if iob > 0.5 {
            parts.append("IOB: \(String(format: "%.1f", iob))U already active")
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

/// Detailed bolus recommendation with breakdown
struct DetailedBolusRecommendation {
    let totalDose: Double
    let correctionComponent: Double
    let mealComponent: Double
    let iobSubtracted: Double
    let currentIOB: Double
    let currentCOB: Double
    let projectedGlucose: Double
    let currentGlucose: Double
    let targetGlucose: Double
    let trend: Double // mg/dL per minute
    let confidence: Double // 0-1
    let reasoning: String
    
    /// Convert to simple MDIRecommendation
    func toMDIRecommendation() -> MDIRecommendation {
        let type: MDIRecommendationType
        if mealComponent > 0 && correctionComponent > 0 {
            type = .combinedBolus
        } else if mealComponent > 0 {
            type = .mealBolus
        } else {
            type = .correctionBolus
        }
        
        // Determine urgency based on glucose levels
        let urgency: MDIUrgencyLevel
        if currentGlucose >= UserDefaults.standard.urgentHighMarkValue ||
           currentGlucose <= UserDefaults.standard.urgentLowMarkValue {
            urgency = .critical
        } else if currentGlucose >= UserDefaults.standard.highMarkValue ||
                  currentGlucose <= UserDefaults.standard.lowMarkValue {
            urgency = .high
        } else {
            urgency = .medium
        }
        
        return MDIRecommendation(
            type: type,
            dose: totalDose > 0 ? totalDose : nil,
            carbs: nil,
            reason: reasoning,
            urgency: urgency,
            expiresAt: Date().addingTimeInterval(urgency == .critical ? 900 : 1800)
        )
    }
}

/// Insulin type enumeration
enum InsulinType: String, CaseIterable {
    case rapid = "Rapid-Acting"
    case humalog = "Humalog/Novolog"
    case fiasp = "Fiasp"
    case lyumjev = "Lyumjev"
    case apidra = "Apidra"
    
    /// Peak time in minutes
    var peakTime: Double {
        switch self {
        case .rapid: return 75
        case .humalog: return 75
        case .fiasp: return 55
        case .lyumjev: return 45
        case .apidra: return 70
        }
    }
    
    /// Duration in minutes
    var duration: Double {
        switch self {
        case .rapid: return 300
        case .humalog: return 300
        case .fiasp: return 300
        case .lyumjev: return 300
        case .apidra: return 240
        }
    }
    
    static func fromString(_ string: String) -> InsulinType? {
        return InsulinType.allCases.first { $0.rawValue == string }
    }
}

// MARK: - Placeholder Types (These should be implemented properly)

struct IOBCalculator {
    init(coreDataManager: CoreDataManager) {}
    
    func calculateIOB(at date: Date, insulinType: InsulinType, insulinSensitivity: Double) -> IOBValue {
        // TODO: Implement actual IOB calculation based on treatment history
        return IOBValue(iob: 0, glucoseDrop: 0, timestamp: date)
    }
}

struct COBCalculator {
    init(coreDataManager: CoreDataManager) {}
    
    func calculateCOB(at date: Date, absorptionRate: Double, delay: Double, carbRatio: Double, insulinSensitivity: Double) -> COBValue {
        // TODO: Implement actual COB calculation based on treatment history
        return COBValue(cob: 0, glucoseRise: 0, timestamp: date)
    }
}

struct IOBValue {
    let iob: Double
    let glucoseDrop: Double
    let timestamp: Date
}

struct COBValue {
    let cob: Double
    let glucoseRise: Double
    let timestamp: Date
}