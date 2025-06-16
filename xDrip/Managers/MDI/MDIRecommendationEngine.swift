import Foundation
import CoreData
import os.log

/// Engine that generates insulin dosing recommendations based on predictions
public class MDIRecommendationEngine {
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let predictionManager: iAPSPredictionManager
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "MDIRecommendationEngine")
    
    /// Recommendation types
    public enum RecommendationType {
        case correction(units: Double, reason: String)
        case meal(units: Double, carbs: Double, reason: String)
        case both(correctionUnits: Double, mealUnits: Double, carbs: Double, reason: String)
        case none(reason: String)
    }
    
    /// Recommendation urgency levels
    public enum RecommendationUrgency {
        case urgent      // Needs action now (high/low)
        case normal      // Standard recommendation
        case optional    // Minor adjustment suggested
    }
    
    /// Safety limits for recommendations
    private struct SafetyLimits {
        let maxCorrectionBolus: Double
        let maxMealBolus: Double
        let minTimeBetweenCorrections: TimeInterval
        let minBGForCorrection: Double
        let maxBGForNoAction: Double
        let maxIOBMultiplier: Double
        
        static func fromUserDefaults() -> SafetyLimits {
            return SafetyLimits(
                maxCorrectionBolus: UserDefaults.standard.mdiMaxCorrectionBolus,
                maxMealBolus: UserDefaults.standard.mdiMaxMealBolus,
                minTimeBetweenCorrections: TimeInterval(UserDefaults.standard.mdiMinTimeBetweenCorrections * 60),
                minBGForCorrection: UserDefaults.standard.mdiMinBGForCorrection,
                maxBGForNoAction: UserDefaults.standard.mdiMaxBGForNoAction,
                maxIOBMultiplier: UserDefaults.standard.mdiMaxIOBMultiplier
            )
        }
    }
    
    /// Recommendation result
    public struct Recommendation {
        public let id: UUID
        public let timestamp: Date
        public let type: RecommendationType
        public let urgency: RecommendationUrgency
        public let currentBG: Double
        public let predictedBG: Double
        public let iob: Double
        public let cob: Double
        public let safetyChecks: [SafetyCheck]
        public let expires: Date
        
        public var isValid: Bool {
            return expires > Date() && safetyChecks.allSatisfy { $0.passed }
        }
        
        /// Format recommendation for notification
        public func formatForNotification() -> (title: String, body: String) {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 1
            
            var title = ""
            var body = ""
            
            switch type {
            case .correction(let units, _):
                title = "Correction Recommended: \(formatter.string(from: NSNumber(value: units)) ?? "0")u"
                body = "Current BG: \(Int(currentBG)) → Predicted: \(Int(predictedBG))"
                
            case .meal(let units, let carbs, _):
                title = "Meal Bolus: \(formatter.string(from: NSNumber(value: units)) ?? "0")u"
                body = "For \(Int(carbs))g carbs. Current BG: \(Int(currentBG))"
                
            case .both(let correction, let meal, let carbs, _):
                let total = correction + meal
                title = "Total Bolus: \(formatter.string(from: NSNumber(value: total)) ?? "0")u"
                body = "\(formatter.string(from: NSNumber(value: meal)) ?? "0")u meal (\(Int(carbs))g) + \(formatter.string(from: NSNumber(value: correction)) ?? "0")u correction"
                
            case .none(let reason):
                title = "No Action Needed"
                body = reason
            }
            
            // Add IOB/COB info if relevant
            if iob > 0.1 || cob > 0.1 {
                body += "\nIOB: \(formatter.string(from: NSNumber(value: iob)) ?? "0")u"
                if cob > 0.1 {
                    body += ", COB: \(Int(cob))g"
                }
            }
            
            return (title, body)
        }
    }
    
    /// Safety check result
    public struct SafetyCheck {
        let name: String
        let passed: Bool
        let message: String
    }
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.predictionManager = iAPSPredictionManager()
    }
    
    // MARK: - Public Methods
    
    /// Generate recommendation based on current state
    public func generateRecommendation(
        bgReadings: [BgReading],
        treatments: [TreatmentEntry],
        pendingCarbs: Double? = nil
    ) -> Recommendation? {
        
        trace("Generating MDI recommendation", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        // Get current state
        guard let currentBG = bgReadings.first else {
            trace("No current BG available", log: log, category: ConstantsLog.categoryRootView, type: .error)
            return nil
        }
        
        // Generate predictions
        guard let predictions = predictionManager.generatePredictions(
            glucose: bgReadings,
            treatments: treatments
        ) else {
            trace("Failed to generate predictions", log: log, category: ConstantsLog.categoryRootView, type: .error)
            return nil
        }
        
        // Extract key values
        let currentBGValue = currentBG.calculatedValue
        let iobValue = calculateCurrentIOB(treatments: treatments)
        let cobValue = calculateCurrentCOB(treatments: treatments)
        let predictedBG = getPredictedBG(predictions: predictions, minutes: 30) // 30 min prediction
        
        // Perform safety checks
        let safetyLimits = SafetyLimits.fromUserDefaults()
        var safetyChecks: [SafetyCheck] = []
        
        // Check 1: Minimum BG for correction
        if currentBGValue < safetyLimits.minBGForCorrection {
            safetyChecks.append(SafetyCheck(
                name: "Minimum BG Check",
                passed: false,
                message: "BG too low for correction (\(Int(currentBGValue)) < \(Int(safetyLimits.minBGForCorrection)))"
            ))
        } else {
            safetyChecks.append(SafetyCheck(
                name: "Minimum BG Check",
                passed: true,
                message: "BG safe for correction"
            ))
        }
        
        // Check 2: Maximum IOB
        let isf = ProfileData.fromUserDefaults().sens
        let maxIOB = isf * safetyLimits.maxIOBMultiplier
        if iobValue > maxIOB {
            safetyChecks.append(SafetyCheck(
                name: "Maximum IOB Check",
                passed: false,
                message: "IOB too high (\(String(format: "%.1f", iobValue)) > \(String(format: "%.1f", maxIOB)))"
            ))
        } else {
            safetyChecks.append(SafetyCheck(
                name: "Maximum IOB Check",
                passed: true,
                message: "IOB within safe limits"
            ))
        }
        
        // Check 3: Recent correction timing
        let recentCorrections = treatments.filter { 
            $0.treatmentType == .Insulin && 
            $0.date > Date().addingTimeInterval(-safetyLimits.minTimeBetweenCorrections)
        }
        if !recentCorrections.isEmpty {
            safetyChecks.append(SafetyCheck(
                name: "Recent Correction Check",
                passed: false,
                message: "Recent correction given \(Int(-recentCorrections[0].date.timeIntervalSinceNow / 60)) min ago"
            ))
        } else {
            safetyChecks.append(SafetyCheck(
                name: "Recent Correction Check",
                passed: true,
                message: "No recent corrections"
            ))
        }
        
        // Determine recommendation type
        let recommendationType = determineRecommendationType(
            currentBG: currentBGValue,
            predictedBG: predictedBG,
            iob: iobValue,
            cob: cobValue,
            pendingCarbs: pendingCarbs,
            safetyLimits: safetyLimits,
            safetyChecks: &safetyChecks
        )
        
        // Determine urgency
        let urgency = determineUrgency(
            currentBG: currentBGValue,
            predictedBG: predictedBG,
            recommendationType: recommendationType
        )
        
        // Create recommendation
        let recommendation = Recommendation(
            id: UUID(),
            timestamp: Date(),
            type: recommendationType,
            urgency: urgency,
            currentBG: currentBGValue,
            predictedBG: predictedBG,
            iob: iobValue,
            cob: cobValue,
            safetyChecks: safetyChecks,
            expires: Date().addingTimeInterval(15 * 60) // 15 minute expiry
        )
        
        trace("Generated recommendation: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, String(describing: recommendationType))
        
        return recommendation
    }
    
    // MARK: - Private Methods
    
    /// Calculate current IOB from treatments
    private func calculateCurrentIOB(treatments: [TreatmentEntry]) -> Double {
        let dia = ProfileData.fromUserDefaults().dia
        let now = Date()
        var totalIOB = 0.0
        
        for treatment in treatments where treatment.treatmentType == .Insulin {
            let minutesAgo = now.timeIntervalSince(treatment.date) / 60.0
            if minutesAgo < dia * 60 {
                // Simple linear decay for now (should use iAPS calculation)
                let iobRemaining = treatment.value * (1.0 - minutesAgo / (dia * 60))
                totalIOB += iobRemaining
            }
        }
        
        return totalIOB
    }
    
    /// Calculate current COB from treatments
    private func calculateCurrentCOB(treatments: [TreatmentEntry]) -> Double {
        let carbAbsorptionTime = 180.0 // 3 hours in minutes
        let now = Date()
        var totalCOB = 0.0
        
        for treatment in treatments where treatment.treatmentType == .Carbs {
            let minutesAgo = now.timeIntervalSince(treatment.date) / 60.0
            if minutesAgo < carbAbsorptionTime {
                // Simple linear absorption for now (should use iAPS calculation)
                let cobRemaining = treatment.value * (1.0 - minutesAgo / carbAbsorptionTime)
                totalCOB += cobRemaining
            }
        }
        
        return totalCOB
    }
    
    /// Get predicted BG at specified minutes in future
    private func getPredictedBG(predictions: iAPSPredictionManager.PredictionResult, minutes: Int) -> Double {
        let index = minutes / 5 // Predictions are in 5-minute intervals
        
        // Use IOB prediction if available, otherwise ZT
        if predictions.iob.count > index {
            return predictions.iob[index]
        } else if predictions.zt.count > index {
            return predictions.zt[index]
        } else {
            // Return last available prediction
            return predictions.iob.last ?? predictions.zt.last ?? 0
        }
    }
    
    /// Determine type of recommendation needed
    private func determineRecommendationType(
        currentBG: Double,
        predictedBG: Double,
        iob: Double,
        cob: Double,
        pendingCarbs: Double?,
        safetyLimits: SafetyLimits,
        safetyChecks: inout [SafetyCheck]
    ) -> RecommendationType {
        
        let profile = ProfileData.fromUserDefaults()
        let targetBG = (profile.min_bg + profile.max_bg) / 2
        let isf = profile.sens
        let carbRatio = profile.carb_ratio
        
        // Check if any critical safety checks failed
        let criticalChecksFailed = safetyChecks.contains { !$0.passed && $0.name != "Recent Correction Check" }
        if criticalChecksFailed {
            return .none(reason: "Safety checks failed")
        }
        
        // Case 1: Pending meal
        if let carbs = pendingCarbs, carbs > 0 {
            let mealInsulin = carbs / carbRatio
            let bgDelta = predictedBG - targetBG
            let correctionInsulin = max(0, bgDelta / isf - iob)
            
            // Apply safety limits
            let safeMealInsulin = min(mealInsulin, safetyLimits.maxMealBolus)
            let safeCorrectionInsulin = min(correctionInsulin, safetyLimits.maxCorrectionBolus)
            
            if safeMealInsulin != mealInsulin {
                safetyChecks.append(SafetyCheck(
                    name: "Meal Bolus Limit",
                    passed: true,
                    message: "Meal bolus limited to \(String(format: "%.1f", safeMealInsulin))u"
                ))
            }
            
            if correctionInsulin > 0 {
                return .both(
                    correctionUnits: safeCorrectionInsulin,
                    mealUnits: safeMealInsulin,
                    carbs: carbs,
                    reason: "Meal bolus with correction"
                )
            } else {
                return .meal(
                    units: safeMealInsulin,
                    carbs: carbs,
                    reason: "Meal bolus for \(Int(carbs))g carbs"
                )
            }
        }
        
        // Case 2: High BG correction
        if predictedBG > safetyLimits.maxBGForNoAction {
            let bgDelta = predictedBG - targetBG
            let correctionInsulin = max(0, bgDelta / isf - iob)
            
            if correctionInsulin > 0 {
                let safeCorrectionInsulin = min(correctionInsulin, safetyLimits.maxCorrectionBolus)
                
                if safeCorrectionInsulin != correctionInsulin {
                    safetyChecks.append(SafetyCheck(
                        name: "Correction Bolus Limit",
                        passed: true,
                        message: "Correction limited to \(String(format: "%.1f", safeCorrectionInsulin))u"
                    ))
                }
                
                return .correction(
                    units: safeCorrectionInsulin,
                    reason: "High BG correction (predicted \(Int(predictedBG)))"
                )
            }
        }
        
        // Case 3: No action needed
        return .none(reason: "BG in range or trending toward target")
    }
    
    /// Determine urgency of recommendation
    private func determineUrgency(
        currentBG: Double,
        predictedBG: Double,
        recommendationType: RecommendationType
    ) -> RecommendationUrgency {
        
        // Urgent if very high or correction needed
        if currentBG > 250 || predictedBG > 300 {
            return .urgent
        }
        
        // Urgent if dropping fast toward low
        if predictedBG < 80 && currentBG > predictedBG {
            return .urgent
        }
        
        // Optional if no action needed
        switch recommendationType {
        case .none:
            return .optional
        case .correction(let units, _) where units < 0.5:
            return .optional
        default:
            return .normal
        }
    }
}

// MARK: - Extensions

extension MDIRecommendationEngine.RecommendationType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .correction(let units, let reason):
            return "Correction: \(String(format: "%.1f", units))u - \(reason)"
        case .meal(let units, let carbs, let reason):
            return "Meal: \(String(format: "%.1f", units))u for \(Int(carbs))g - \(reason)"
        case .both(let correction, let meal, let carbs, let reason):
            return "Both: \(String(format: "%.1f", correction + meal))u (\(String(format: "%.1f", correction))u corr + \(String(format: "%.1f", meal))u meal) - \(reason)"
        case .none(let reason):
            return "No action: \(reason)"
        }
    }
}

