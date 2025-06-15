import Foundation
import JavaScriptCore
import os.log
import CoreData

/// Simplified iAPS prediction manager for testing JavaScript execution
class iAPSPredictionManager {
    
    private let jsWorker = JavaScriptWorker()
    private let glucoseConverter = GlucoseDataConverter()
    private let treatmentConverter = TreatmentDataConverter()
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    init() {
        trace("iAPSPredictionManager initialized", log: log, category: ConstantsLog.categoryRootView, type: .info)
    }
    
    /// Test function to verify JavaScript execution works
    func testJavaScriptExecution() -> Bool {
        do {
            // Load the IOB JavaScript bundle
            guard let iobPath = Bundle.main.path(forResource: "iob", ofType: "js") else {
                trace("Could not find iob.js bundle", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return false
            }
            
            let iobScript = try String(contentsOfFile: iobPath)
            
            // Create a test script that includes the IOB functions
            let testScript = Script(name: "test", body: """
                \(iobScript)
                
                // Test with empty pump history
                var testResult = generate([], {"dia": 4}, new Date().toISOString(), null);
                JSON.stringify(testResult);
            """)
            
            // Execute the script
            let result = jsWorker.evaluate(script: testScript)
            
            if let resultString = result?.toString() {
                trace("JavaScript test successful: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, resultString)
                return true
            } else {
                trace("JavaScript test failed - no result", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return false
            }
            
        } catch {
            trace("JavaScript test error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            return false
        }
    }
    
    /// Generate predictions using iAPS algorithms
    func generatePredictions(glucose: [BgReading], treatments: [TreatmentEntry]) -> PredictionResult? {
        trace("Starting iAPS prediction generation", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        do {
            // Convert data to JavaScript format
            let glucoseData = glucoseConverter.convertToJavaScriptFormat(bgReadings: glucose)
            let pumpHistory = treatmentConverter.convertToJavaScriptFormat(treatments: treatments)
            let profile = ProfileData.fromUserDefaults()
            
            // Calculate IOB
            if let iobResult = calculateIOB(pumpHistory: pumpHistory, profile: profile) {
                trace("IOB calculated: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, iobResult.description)
            }
            
            // Calculate COB
            if let cobResult = calculateCOB(pumpHistory: pumpHistory, profile: profile) {
                trace("COB calculated: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .info, cobResult.description)
            }
            
            // Generate predictions
            if let predictions = runPredictionAlgorithm(glucose: glucoseData, pumpHistory: pumpHistory, profile: profile) {
                return predictions
            }
            
        } catch {
            trace("Error generating predictions: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        return nil
    }
    
    /// Calculate Insulin on Board (IOB)
    private func calculateIOB(pumpHistory: [[String: Any]], profile: ProfileData) -> [String: Any]? {
        do {
            // Load IOB JavaScript
            guard let iobPath = Bundle.main.path(forResource: "iob", ofType: "js") else {
                trace("Could not find iob.js", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return nil
            }
            
            let iobScript = try String(contentsOfFile: iobPath)
            
            // Convert data to JSON strings
            let pumpHistoryJSON = try JSONSerialization.data(withJSONObject: pumpHistory)
            let pumpHistoryString = String(data: pumpHistoryJSON, encoding: .utf8) ?? "[]"
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            // Create IOB calculation script
            let script = Script(name: "iob", body: """
                \(iobScript)
                
                var pumpHistory = \(pumpHistoryString);
                var profile = \(profileString);
                var currentTime = "\(currentTime)";
                
                var iobResult = generate(pumpHistory, profile, currentTime);
                JSON.stringify(iobResult);
            """)
            
            // Execute script
            if let result = jsWorker.evaluate(script: script),
               let resultString = result.toString() {
                // Parse result
                if let data = resultString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
            }
            
        } catch {
            trace("IOB calculation error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        return nil
    }
    
    /// Calculate Carbs on Board (COB)
    private func calculateCOB(pumpHistory: [[String: Any]], profile: ProfileData) -> [String: Any]? {
        do {
            // Load meal (COB) JavaScript
            guard let mealPath = Bundle.main.path(forResource: "meal", ofType: "js") else {
                trace("Could not find meal.js", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return nil
            }
            
            let mealScript = try String(contentsOfFile: mealPath)
            
            // Convert data to JSON strings
            let pumpHistoryJSON = try JSONSerialization.data(withJSONObject: pumpHistory)
            let pumpHistoryString = String(data: pumpHistoryJSON, encoding: .utf8) ?? "[]"
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            // Create COB calculation script
            let script = Script(name: "cob", body: """
                \(mealScript)
                
                var pumpHistory = \(pumpHistoryString);
                var profile = \(profileString);
                var currentTime = "\(currentTime)";
                
                var cobResult = generate(pumpHistory, profile, currentTime);
                JSON.stringify(cobResult);
            """)
            
            // Execute script
            if let result = jsWorker.evaluate(script: script),
               let resultString = result.toString() {
                // Parse result
                if let data = resultString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
            }
            
        } catch {
            trace("COB calculation error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        return nil
    }
    
    /// Run the main prediction algorithm
    private func runPredictionAlgorithm(glucose: [[String: Any]], pumpHistory: [[String: Any]], profile: ProfileData) -> PredictionResult? {
        // For now, return mock predictions
        // Full implementation will use determine-basal.js
        
        let mockPredictions = PredictionResult(
            iob: [100, 98, 95, 92, 89, 85, 82, 78, 75, 72], // Mock IOB prediction
            cob: [120, 125, 130, 128, 125, 120, 115, 110, 105, 100], // Mock COB prediction
            zt: [100, 100, 100, 100, 100, 100, 100, 100, 100, 100], // Mock zero-temp prediction
            uam: [100, 105, 110, 115, 118, 120, 122, 125, 127, 130] // Mock UAM prediction
        )
        
        trace("Generated mock predictions for testing", log: log, category: ConstantsLog.categoryRootView, type: .info)
        
        return mockPredictions
    }
}

struct PredictionResult {
    let iob: [Double]  // IOB prediction values
    let cob: [Double]  // COB prediction values
    let zt: [Double]   // Zero-temp predictions
    let uam: [Double]  // Unannounced meal predictions
}

// MARK: - Data Converters

/// Converts xDripSwift BgReading objects to iAPS GlucoseEntry format
class GlucoseDataConverter {
    
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// Convert BgReading array to JavaScript-compatible glucose array format
    /// Expected format: [{"glucose": 120, "date": "2024-01-01T12:00:00Z", "dateString": "2024-01-01T12:00:00Z"}]
    func convertToJavaScriptFormat(bgReadings: [BgReading]) -> [[String: Any]] {
        var glucoseArray: [[String: Any]] = []
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for reading in bgReadings {
            // Skip invalid readings
            guard reading.calculatedValue >= 40 && reading.calculatedValue < 400 else {
                continue
            }
            
            let dateString = dateFormatter.string(from: reading.timeStamp)
            
            let glucoseEntry: [String: Any] = [
                "glucose": Int(reading.calculatedValue), // iAPS expects mg/dL as Int
                "date": dateString,
                "dateString": dateString,
                "type": "sgv" // sensor glucose value
            ]
            
            glucoseArray.append(glucoseEntry)
        }
        
        // Sort by date descending (newest first) as iAPS expects
        glucoseArray.sort { entry1, entry2 in
            guard let date1 = entry1["date"] as? String,
                  let date2 = entry2["date"] as? String else {
                return false
            }
            return date1 > date2
        }
        
        trace("Converted %{public}d BgReadings to JavaScript format", log: log, category: ConstantsLog.categoryRootView, type: .info, glucoseArray.count)
        
        return glucoseArray
    }
}

/// Converts xDripSwift TreatmentEntry objects to iAPS format for pump history
class TreatmentDataConverter {
    
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// Convert TreatmentEntry array to JavaScript-compatible pump history format
    /// Pump history includes boluses, carbs, and temp basals
    func convertToJavaScriptFormat(treatments: [TreatmentEntry]) -> [[String: Any]] {
        var pumpHistory: [[String: Any]] = []
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for treatment in treatments {
            let timestamp = dateFormatter.string(from: treatment.date)
            
            switch treatment.treatmentType {
            case .Insulin:
                // Create bolus entry
                let bolusEntry: [String: Any] = [
                    "_type": "Bolus",
                    "timestamp": timestamp,
                    "amount": treatment.value,
                    "duration": 0, // xDripSwift doesn't track extended boluses
                    "type": "normal",
                    "created_at": timestamp
                ]
                pumpHistory.append(bolusEntry)
                
            case .Carbs:
                // Create carb entry
                let carbEntry: [String: Any] = [
                    "_type": "Meal Bolus",
                    "timestamp": timestamp,
                    "carbs": Int(treatment.value),
                    "created_at": timestamp
                ]
                pumpHistory.append(carbEntry)
                
            case .Basal:
                // Create temp basal entry
                let tempBasalEntry: [String: Any] = [
                    "_type": "TempBasal",
                    "timestamp": timestamp,
                    "rate": treatment.value,
                    "duration": Int(treatment.valueSecondary ?? 30), // Use secondary value for duration, default 30 min
                    "created_at": timestamp
                ]
                pumpHistory.append(tempBasalEntry)
                
            default:
                // Skip other treatment types for pump history
                break
            }
        }
        
        // Sort by timestamp descending (newest first)
        pumpHistory.sort { entry1, entry2 in
            guard let timestamp1 = entry1["timestamp"] as? String,
                  let timestamp2 = entry2["timestamp"] as? String else {
                return false
            }
            return timestamp1 > timestamp2
        }
        
        trace("Converted %{public}d treatments to pump history format", log: log, category: ConstantsLog.categoryRootView, type: .info, pumpHistory.count)
        
        return pumpHistory
    }
}

/// Profile data structure matching OpenAPS profile format
struct ProfileData {
    // Basic settings
    let dia: Double // Duration of insulin action in hours
    let carb_ratio: Double // grams per unit
    let sens: Double // mg/dL per unit (ISF)
    let max_iob: Double // max allowed IOB
    let max_daily_basal: Double
    let max_basal_rate: Double
    let min_bg: Double // target minimum BG
    let max_bg: Double // target maximum BG
    
    // Basal rates - simplified for MDI
    let basal_rate: Double // units per hour
    
    // Optional advanced settings
    let insulinPeakTime: Int? // minutes
    let carbsPerHour: Double? // carb absorption rate
    let delayMinutes: Int? // insulin delay
    
    init(
        dia: Double = 4.0,
        carb_ratio: Double = 10.0,
        sens: Double = 50.0,
        max_iob: Double = 0.0, // 0 for MDI (no pump basal)
        max_daily_basal: Double = 0.0,
        max_basal_rate: Double = 0.0,
        min_bg: Double = 100.0,
        max_bg: Double = 120.0,
        basal_rate: Double = 0.0,
        insulinPeakTime: Int? = nil,
        carbsPerHour: Double? = nil,
        delayMinutes: Int? = nil
    ) {
        self.dia = dia
        self.carb_ratio = carb_ratio
        self.sens = sens
        self.max_iob = max_iob
        self.max_daily_basal = max_daily_basal
        self.max_basal_rate = max_basal_rate
        self.min_bg = min_bg
        self.max_bg = max_bg
        self.basal_rate = basal_rate
        self.insulinPeakTime = insulinPeakTime
        self.carbsPerHour = carbsPerHour
        self.delayMinutes = delayMinutes
    }
    
    /// Create profile from UserDefaults
    static func fromUserDefaults() -> ProfileData {
        let userDefaults = UserDefaults.standard
        
        // Get values from UserDefaults or use defaults
        let dia = userDefaults.object(forKey: "insulinDuration") as? Double ?? 4.0
        let carbRatio = userDefaults.object(forKey: "carbRatio") as? Double ?? 10.0
        let isf = userDefaults.object(forKey: "insulinSensitivityFactor") as? Double ?? 50.0
        
        // Convert target values to mg/dL if needed
        let isMgDl = userDefaults.bloodGlucoseUnitIsMgDl
        let minBgUserUnit = userDefaults.object(forKey: "targetMinBG") as? Double ?? 100.0
        let maxBgUserUnit = userDefaults.object(forKey: "targetMaxBG") as? Double ?? 120.0
        
        let minBg = isMgDl ? minBgUserUnit : minBgUserUnit * 18.0 // Convert mmol/L to mg/dL
        let maxBg = isMgDl ? maxBgUserUnit : maxBgUserUnit * 18.0
        
        return ProfileData(
            dia: dia,
            carb_ratio: carbRatio,
            sens: isf,
            max_iob: 0.0, // MDI users don't have pump basal
            max_daily_basal: 0.0,
            max_basal_rate: 0.0,
            min_bg: minBg,
            max_bg: maxBg,
            basal_rate: 0.0
        )
    }
    
    /// Convert to JavaScript-compatible dictionary
    func toJavaScriptFormat() -> [String: Any] {
        var dict: [String: Any] = [
            "dia": dia,
            "carb_ratio": carb_ratio,
            "sens": sens,
            "max_iob": max_iob,
            "max_daily_basal": max_daily_basal,
            "max_basal_rate": max_basal_rate,
            "min_bg": min_bg,
            "max_bg": max_bg,
            "current_basal": basal_rate
        ]
        
        if let insulinPeakTime = insulinPeakTime {
            dict["insulinPeakTime"] = insulinPeakTime
        }
        if let carbsPerHour = carbsPerHour {
            dict["carbsPerHour"] = carbsPerHour
        }
        if let delayMinutes = delayMinutes {
            dict["delayMinutes"] = delayMinutes
        }
        
        return dict
    }
}