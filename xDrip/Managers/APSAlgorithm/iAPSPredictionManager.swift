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
    private var debugLogs: [String] = []
    
    init() {
        trace("iAPSPredictionManager initialized", log: log, category: ConstantsLog.categoryRootView, type: .info)
        debugLogs.removeAll()
    }
    
    /// Add debug log entry
    private func debugLog(_ message: String) {
        let timestamp = Date().formatted(.dateTime.hour().minute().second())
        let logEntry = "[\(timestamp)] \(message)"
        debugLogs.append(logEntry)
        // Also log to console for development
        print("iAPS DEBUG: \(message)")
    }
    
    /// Get all debug logs
    func getDebugLogs() -> String {
        return debugLogs.joined(separator: "\n")
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
        debugLog("Starting iAPS prediction generation")
        debugLog("Input: \(glucose.count) BG readings, \(treatments.count) treatments")
        
        // Convert data to JavaScript format
        let glucoseData = glucoseConverter.convertToJavaScriptFormat(bgReadings: glucose)
        let pumpHistory = treatmentConverter.convertToJavaScriptFormat(treatments: treatments)
        let profile = ProfileData.fromUserDefaults()
        
        debugLog("Converted: \(glucoseData.count) glucose entries, \(pumpHistory.count) pump history entries")
        debugLog("Profile: DIA=\(profile.dia)h, ISF=\(profile.sens), CR=\(profile.carb_ratio)")
        
        // Calculate IOB
        if let iobResult = calculateIOB(pumpHistory: pumpHistory, profile: profile) {
            debugLog("IOB calculated: \(iobResult)")
        } else {
            debugLog("IOB calculation failed")
        }
        
        // Calculate COB
        if let cobResult = calculateCOB(pumpHistory: pumpHistory, profile: profile, glucose: glucoseData) {
            debugLog("COB calculated: \(cobResult)")
        } else {
            debugLog("COB calculation failed")
        }
        
        // Generate predictions
        if let predictions = runPredictionAlgorithm(glucose: glucoseData, pumpHistory: pumpHistory, profile: profile) {
            debugLog("Predictions generated successfully")
            return predictions
        }
        
        debugLog("Failed to generate predictions")
        return nil
    }
    
    /// Calculate full IOB array for predictions
    private func calculateIOBArray(pumpHistory: [[String: Any]], profile: ProfileData) -> [[String: Any]]? {
        debugLog("calculateIOBArray: Starting with \(pumpHistory.count) pump history entries")
        do {
            // Load IOB JavaScript
            guard let iobPath = Bundle.main.path(forResource: "iob", ofType: "js") else {
                debugLog("ERROR: Could not find iob.js")
                return nil
            }
            
            debugLog("Found iob.js at: \(iobPath)")
            let iobScript = try String(contentsOfFile: iobPath)
            debugLog("IOB script loaded, length: \(iobScript.count) characters")
            
            // Convert data to JSON strings
            let pumpHistoryJSON = try JSONSerialization.data(withJSONObject: pumpHistory)
            let pumpHistoryString = String(data: pumpHistoryJSON, encoding: .utf8) ?? "[]"
            debugLog("Pump history JSON: \(pumpHistoryString.prefix(200))...")
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            debugLog("Profile JSON: \(profileString)")
            
            let currentTime = ISO8601DateFormatter().string(from: Date())
            debugLog("Current time: \(currentTime)")
            
            // Create IOB calculation script that returns the FULL array
            let script = Script(name: "iobArray", body: """
                \(iobScript)
                
                console.log("IOB Array Script: Starting execution");
                var pumpHistory = \(pumpHistoryString);
                console.log("IOB Array Script: Pump history loaded, entries:", pumpHistory.length);
                var profile = \(profileString);
                console.log("IOB Array Script: Profile loaded, DIA:", profile.dia);
                var currentTime = "\(currentTime)";
                
                try {
                    console.log("IOB Array Script: Checking freeaps_iob availability");
                    if (typeof freeaps_iob === 'undefined') {
                        console.error("IOB Array Script: freeaps_iob is not defined");
                        JSON.stringify({error: "freeaps_iob is not defined"});
                    } else {
                        console.log("IOB Array Script: freeaps_iob is available, type:", typeof freeaps_iob);
                        
                        // Create inputs object for iAPS IOB calculation
                        var inputs = {
                            history: pumpHistory,
                            profile: profile,
                            clock: currentTime
                        };
                        
                        console.log("IOB Array Script: Calling freeaps_iob with inputs");
                        var iobResult = freeaps_iob(inputs);
                        console.log("IOB Array Script: Result array length:", iobResult ? iobResult.length : 0);
                        
                        // Return the FULL array for determine-basal
                        if (iobResult && iobResult.length > 0) {
                            console.log("IOB Array Script: First IOB:", iobResult[0].iob, "Last IOB:", iobResult[iobResult.length-1].iob);
                            JSON.stringify(iobResult);
                        } else {
                            JSON.stringify({error: "No IOB result returned"});
                        }
                    }
                } catch (error) {
                    console.error("IOB Array Script Error:", error.toString());
                    console.error("IOB Array Script Stack:", error.stack);
                    JSON.stringify({error: error.toString()});
                }
            """)
            
            // Clear and execute
            jsWorker.clearCapturedLogs()
            let result = jsWorker.evaluate(script: script)
            
            // Capture logs
            let jsLogs = jsWorker.getCapturedLogs()
            for log in jsLogs {
                debugLog("IOB Array JS: \(log)")
            }
            
            if let result = result,
               let resultString = result.toString() {
                debugLog("IOB array result length: \(resultString.count) chars")
                // Parse result
                if let data = resultString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    debugLog("IOB array calculation successful, \(json.count) entries")
                    return json
                } else if let data = resultString.data(using: .utf8),
                          let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let error = errorJson["error"] as? String {
                    debugLog("IOB array JavaScript error: \(error)")
                    return nil
                }
            } else {
                debugLog("IOB array: No result from JavaScript execution")
            }
            
        } catch {
            debugLog("IOB array calculation exception: \(error.localizedDescription)")
            trace("IOB array calculation error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        debugLog("IOB array calculation failed")
        return nil
    }
    
    /// Calculate Insulin on Board (IOB) - returns just the current IOB
    private func calculateIOB(pumpHistory: [[String: Any]], profile: ProfileData) -> [String: Any]? {
        debugLog("calculateIOB: Starting with \(pumpHistory.count) pump history entries")
        do {
            // Load IOB JavaScript
            guard let iobPath = Bundle.main.path(forResource: "iob", ofType: "js") else {
                debugLog("ERROR: Could not find iob.js")
                return nil
            }
            
            debugLog("Found iob.js at: \(iobPath)")
            let iobScript = try String(contentsOfFile: iobPath)
            debugLog("IOB script loaded, length: \(iobScript.count) characters")
            
            // Convert data to JSON strings
            let pumpHistoryJSON = try JSONSerialization.data(withJSONObject: pumpHistory)
            let pumpHistoryString = String(data: pumpHistoryJSON, encoding: .utf8) ?? "[]"
            debugLog("Pump history JSON: \(pumpHistoryString.prefix(200))...")
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            debugLog("Profile JSON: \(profileString)")
            
            let currentTime = ISO8601DateFormatter().string(from: Date())
            debugLog("Current time: \(currentTime)")
            
            // Create IOB calculation script
            let script = Script(name: "iob", body: """
                \(iobScript)
                
                console.log("IOB Script: Starting execution");
                var pumpHistory = \(pumpHistoryString);
                console.log("IOB Script: Pump history loaded, entries:", pumpHistory.length);
                var profile = \(profileString);
                console.log("IOB Script: Profile loaded, DIA:", profile.dia);
                var currentTime = "\(currentTime)";
                
                try {
                    console.log("IOB Script: Checking freeaps_iob availability");
                    if (typeof freeaps_iob === 'undefined') {
                        console.error("IOB Script: freeaps_iob is not defined");
                        JSON.stringify({error: "freeaps_iob is not defined"});
                    } else {
                        console.log("IOB Script: freeaps_iob is available, type:", typeof freeaps_iob);
                        
                        // Create inputs object for iAPS IOB calculation
                        var inputs = {
                            history: pumpHistory,
                            profile: profile,
                            clock: currentTime
                        };
                        
                        console.log("IOB Script: Calling freeaps_iob with inputs");
                        var iobResult = freeaps_iob(inputs);
                        console.log("IOB Script: Result:", JSON.stringify(iobResult));
                        
                        // Extract the first IOB result (current time)
                        if (iobResult && iobResult.length > 0) {
                            JSON.stringify(iobResult[0]);
                        } else {
                            JSON.stringify({error: "No IOB result returned"});
                        }
                    }
                } catch (error) {
                    console.error("IOB Script Error:", error.toString());
                    console.error("IOB Script Stack:", error.stack);
                    JSON.stringify({error: error.toString()});
                }
            """)
            
            // Clear and execute
            jsWorker.clearCapturedLogs()
            let result = jsWorker.evaluate(script: script)
            
            // Capture logs
            let jsLogs = jsWorker.getCapturedLogs()
            for log in jsLogs {
                debugLog("IOB JS: \(log)")
            }
            
            if let result = result,
               let resultString = result.toString() {
                debugLog("IOB result string: \(resultString)")
                // Parse result
                if let data = resultString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? String {
                        debugLog("IOB JavaScript error: \(error)")
                        return nil
                    }
                    debugLog("IOB calculation successful")
                    return json
                }
            } else {
                debugLog("IOB: No result from JavaScript execution")
            }
            
        } catch {
            debugLog("IOB calculation exception: \(error.localizedDescription)")
            trace("IOB calculation error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        debugLog("IOB calculation failed")
        return nil
    }
    
    /// Calculate Carbs on Board (COB)
    private func calculateCOB(pumpHistory: [[String: Any]], profile: ProfileData, glucose: [[String: Any]]) -> [String: Any]? {
        debugLog("calculateCOB: Starting")
        do {
            // Load meal (COB) JavaScript
            guard let mealPath = Bundle.main.path(forResource: "meal", ofType: "js") else {
                debugLog("ERROR: Could not find meal.js")
                trace("Could not find meal.js", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return nil
            }
            
            debugLog("Found meal.js at: \(mealPath)")
            let mealScript = try String(contentsOfFile: mealPath)
            debugLog("Meal script loaded, length: \(mealScript.count) characters")
            
            // Convert data to JSON strings
            let pumpHistoryJSON = try JSONSerialization.data(withJSONObject: pumpHistory)
            let pumpHistoryString = String(data: pumpHistoryJSON, encoding: .utf8) ?? "[]"
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            
            let glucoseJSON = try JSONSerialization.data(withJSONObject: glucose)
            let glucoseString = String(data: glucoseJSON, encoding: .utf8) ?? "[]"
            
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            // Create COB calculation script
            let script = Script(name: "cob", body: """
                \(mealScript)
                
                console.log("COB Script: Starting execution");
                var pumpHistory = \(pumpHistoryString);
                console.log("COB Script: Pump history loaded, entries:", pumpHistory.length);
                var profile = \(profileString);
                console.log("COB Script: Profile loaded");
                var glucoseData = \(glucoseString);
                console.log("COB Script: Glucose data loaded, entries:", glucoseData.length);
                var currentTime = "\(currentTime)";
                
                try {
                    console.log("COB Script: Checking freeaps_meal availability");
                    if (typeof freeaps_meal === 'undefined') {
                        console.error("COB Script: freeaps_meal is not defined");
                        JSON.stringify({error: "freeaps_meal is not defined"});
                    } else {
                        console.log("COB Script: freeaps_meal is available, type:", typeof freeaps_meal);
                        
                        // Find carb entries from pump history
                        var carbs = [];
                        for (var i = 0; i < pumpHistory.length; i++) {
                            var entry = pumpHistory[i];
                            if (entry.carbs && entry.carbs > 0) {
                                carbs.push({
                                    created_at: entry.created_at,
                                    carbs: entry.carbs
                                });
                            }
                        }
                        console.log("COB Script: Found", carbs.length, "carb entries");
                        
                        // Create inputs object with all required properties
                        var inputs = {
                            history: pumpHistory,
                            carbs: carbs,
                            profile: profile,
                            glucose: glucoseData,
                            basalprofile: profile.basalprofile || []
                        };
                        
                        console.log("COB Script: Calling freeaps_meal with inputs");
                        var cobResult = freeaps_meal(inputs);
                        console.log("COB Script: Result:", JSON.stringify(cobResult));
                        
                        // freeaps_meal returns meal data including mealCOB
                        if (cobResult) {
                            JSON.stringify(cobResult);
                        } else {
                            JSON.stringify({error: "No COB result returned"});
                        }
                    }
                } catch (error) {
                    console.error("COB Script Error:", error.toString());
                    console.error("COB Script Stack:", error.stack);
                    JSON.stringify({error: error.toString()});
                }
            """)
            
            // Clear and execute
            jsWorker.clearCapturedLogs()
            let result = jsWorker.evaluate(script: script)
            
            // Capture logs
            let jsLogs = jsWorker.getCapturedLogs()
            for log in jsLogs {
                debugLog("COB JS: \(log)")
            }
            
            if let result = result,
               let resultString = result.toString() {
                debugLog("COB result string: \(resultString)")
                // Parse result
                if let data = resultString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? String {
                        debugLog("COB JavaScript error: \(error)")
                        return nil
                    }
                    debugLog("COB calculation successful")
                    return json
                }
            } else {
                debugLog("COB: No result from JavaScript execution")
            }
            
        } catch {
            debugLog("COB calculation exception: \(error.localizedDescription)")
            trace("COB calculation error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
        }
        
        debugLog("COB calculation failed")
        return nil
    }
    
    /// Run the main prediction algorithm using iAPS determine-basal
    private func runPredictionAlgorithm(glucose: [[String: Any]], pumpHistory: [[String: Any]], profile: ProfileData) -> PredictionResult? {
        do {
            // Get current glucose
            guard let currentGlucose = glucose.first else {
                trace("No current glucose available", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return nil
            }
            
            // Calculate IOB array and COB using JavaScript
            let iobArrayData = calculateIOBArray(pumpHistory: pumpHistory, profile: profile)
            let cobData = calculateCOB(pumpHistory: pumpHistory, profile: profile, glucose: glucose)
            
            if iobArrayData == nil || iobArrayData?.isEmpty == true {
                debugLog("ERROR: Failed to calculate IOB array")
                return nil
            }
            
            if cobData == nil {
                debugLog("ERROR: Failed to calculate COB") 
                return nil
            }
            
            guard let iobArray = iobArrayData, 
                  let iob = iobArray.first,
                  let cob = cobData else {
                return nil
            }
            
            // Load determine-basal JavaScript
            guard let determineBasalPath = Bundle.main.path(forResource: "determine-basal", ofType: "js") else {
                trace("Could not find determine-basal.js", log: log, category: ConstantsLog.categoryRootView, type: .error)
                return nil
            }
            
            let determineBasalScript = try String(contentsOfFile: determineBasalPath)
            
            // Prepare glucose data for determine-basal (needs specific format)
            var glucoseStatus: [String: Any] = [:]
            if let glucoseValue = currentGlucose["glucose"] as? Int,
               let date = currentGlucose["date"] as? String {
                // Calculate delta from recent glucose values
                var delta = 0
                var short_avgdelta = 0.0
                var long_avgdelta = 0.0
                
                if glucose.count > 1,
                   let prev = glucose[1]["glucose"] as? Int {
                    delta = glucoseValue - prev
                }
                
                // Calculate short average delta (15 min)
                if glucose.count > 3 {
                    var sum = 0
                    for i in 0..<min(3, glucose.count - 1) {
                        if let curr = glucose[i]["glucose"] as? Int,
                           let next = glucose[i + 1]["glucose"] as? Int {
                            sum += (curr - next)
                        }
                    }
                    short_avgdelta = Double(sum) / 3.0
                }
                
                // Calculate long average delta (30 min)
                if glucose.count > 6 {
                    var sum = 0
                    for i in 0..<min(6, glucose.count - 1) {
                        if let curr = glucose[i]["glucose"] as? Int,
                           let next = glucose[i + 1]["glucose"] as? Int {
                            sum += (curr - next)
                        }
                    }
                    long_avgdelta = Double(sum) / 6.0
                }
                
                glucoseStatus = [
                    "glucose": glucoseValue,
                    "date": date,
                    "noise": 0,
                    "delta": delta,
                    "short_avgdelta": short_avgdelta,
                    "long_avgdelta": long_avgdelta
                ]
            }
            
            // Current temp (none for MDI)
            let currentTemp: [String: Any] = [
                "duration": 0,
                "rate": 0
            ]
            
            // Autosens data (default to 1.0 ratio)
            let autosensData = [
                "ratio": 1.0
            ]
            
            // Convert data to JSON
            let glucoseStatusJSON = try JSONSerialization.data(withJSONObject: glucoseStatus)
            let glucoseStatusString = String(data: glucoseStatusJSON, encoding: .utf8) ?? "{}"
            
            let currentTempJSON = try JSONSerialization.data(withJSONObject: currentTemp)
            let currentTempString = String(data: currentTempJSON, encoding: .utf8) ?? "{}"
            
            // Pass the iobArray directly as iob_data - this is what determine-basal expects
            let iobDataJSON = try JSONSerialization.data(withJSONObject: iobArray)
            let iobDataString = String(data: iobDataJSON, encoding: .utf8) ?? "[]"
            
            let profileJSON = try JSONSerialization.data(withJSONObject: profile.toJavaScriptFormat())
            let profileString = String(data: profileJSON, encoding: .utf8) ?? "{}"
            
            let autosensJSON = try JSONSerialization.data(withJSONObject: autosensData)
            let autosensString = String(data: autosensJSON, encoding: .utf8) ?? "{}"
            
            let mealDataJSON = try JSONSerialization.data(withJSONObject: cob)
            let mealDataString = String(data: mealDataJSON, encoding: .utf8) ?? "{}"
            
            // Create determine-basal script
            // Debug the inputs
            debugLog("glucoseStatus: \(glucoseStatusString)")
            debugLog("iob_data: \(iobDataString)")
            debugLog("meal_data: \(mealDataString)")
            
            let script = Script(name: "determineBasal", body: """
                // Shim for process object that iAPS expects
                var process = {
                    stderr: {
                        write: function(text) {
                            console.error("Process stderr:", text);
                        }
                    },
                    exit: function(code) {
                        console.error("Process exit called with code:", code);
                    }
                };
                
                \(determineBasalScript)
                
                var glucose_status = \(glucoseStatusString);
                var currenttemp = \(currentTempString);
                var iob_data = \(iobDataString);  // Now includes iobArray
                var profile = \(profileString);
                var autosens_data = \(autosensString);
                var meal_data = \(mealDataString);
                var microBolusAllowed = false;
                var reservoir = 100; // dummy value
                var clock = new Date();
                
                // Create tempBasalMethods object with setTempBasal and getMaxSafeBasal methods
                var tempBasalMethods = {
                    setTempBasal: function(rate, duration, profile, rT, currenttemp) {
                        return rT;  // Return the recommendation object unchanged
                    },
                    getMaxSafeBasal: function(profile) {
                        // Return a reasonable maximum basal rate for MDI
                        return profile.max_basal_rate || 10;
                    }
                };
                
                try {
                    console.log("Checking freeaps_determineBasal availability");
                    if (typeof freeaps_determineBasal === 'undefined') {
                        console.error("freeaps_determineBasal is not defined");
                        JSON.stringify({error: "freeaps_determineBasal is not defined"});
                    } else {
                        console.log("freeaps_determineBasal is available, type:", typeof freeaps_determineBasal);
                        
                        // Call determine-basal with tempBasalMethods as 7th parameter
                        var result = freeaps_determineBasal(glucose_status, currenttemp, iob_data, profile, 
                                                            autosens_data, meal_data, 
                                                            tempBasalMethods, microBolusAllowed, 
                                                            reservoir, clock);
                        
                        // Log the full result for debugging
                        console.log("Full determine-basal result:", JSON.stringify(result));
                        
                        // Extract predictions
                        var predictions = {};
                        if (result && result.predBGs) {
                            predictions = result.predBGs;
                            console.log("Found predictions:", JSON.stringify(predictions));
                        } else {
                            console.log("No predBGs in result");
                        }
                        
                        JSON.stringify(predictions);
                    }
                } catch (error) {
                    console.error("Error in determine-basal:", error.toString());
                    console.error("Stack trace:", error.stack);
                    JSON.stringify({error: error.toString()});
                }
            """)
            
            // Clear previous logs
            jsWorker.clearCapturedLogs()
            
            // Execute script
            let result = jsWorker.evaluate(script: script)
            
            // Capture JavaScript logs
            let jsLogs = jsWorker.getCapturedLogs()
            for log in jsLogs {
                debugLog("JS: \(log)")
            }
            
            if let result = result,
               let resultString = result.toString() {
                debugLog("Determine-basal raw result: \(resultString)")
                
                // Parse predictions
                if let data = resultString.data(using: .utf8),
                   let predictions = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    debugLog("Parsed predictions: \(predictions)")
                    
                    // Check for error
                    if let error = predictions["error"] as? String {
                        debugLog("JavaScript error: \(error)")
                        return nil
                    }
                    
                    // Extract prediction arrays
                    let iobPred = predictions["IOB"] as? [Double] ?? []
                    let cobPred = predictions["COB"] as? [Double] ?? []
                    let ztPred = predictions["ZT"] as? [Double] ?? []
                    let uamPred = predictions["UAM"] as? [Double] ?? []
                    
                    debugLog("IOB predictions: \(iobPred.count) values")
                    debugLog("COB predictions: \(cobPred.count) values")
                    debugLog("ZT predictions: \(ztPred.count) values")
                    debugLog("UAM predictions: \(uamPred.count) values")
                    
                    return PredictionResult(
                        iob: iobPred,
                        cob: cobPred,
                        zt: ztPred,
                        uam: uamPred
                    )
                } else {
                    debugLog("Failed to parse predictions from: \(resultString)")
                }
            } else {
                debugLog("No result from JavaScript execution")
            }
            
            trace("Failed to generate predictions from determine-basal", log: log, category: ConstantsLog.categoryRootView, type: .error)
            return nil
            
        } catch {
            trace("Prediction algorithm error: %{public}@", log: log, category: ConstantsLog.categoryRootView, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - These methods are kept for reference but not used - we use JavaScript IOB/COB instead
    /*
    /// Calculate IOB array for predictions
    private func calculateIOBArray(pumpHistory: [[String: Any]], profile: ProfileData) -> [String: Any] {
        // Simplified IOB calculation
        var totalIOB = 0.0
        var totalActivity = 0.0
        
        let now = Date()
        let dia = profile.dia * 60 // Convert hours to minutes
        var bolusCount = 0
        
        trace("Calculating IOB with DIA: %{public}f hours, ISF: %{public}f", 
              log: log, category: ConstantsLog.categoryRootView, type: .info,
              profile.dia, profile.sens)
        
        for entry in pumpHistory {
            guard let type = entry["_type"] as? String,
                  type == "Bolus",
                  let amount = entry["amount"] as? Double,
                  let timestampStr = entry["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampStr) else {
                continue
            }
            
            let minutesAgo = now.timeIntervalSince(timestamp) / 60.0
            
            if minutesAgo < dia {
                // Simple linear IOB decay
                let iobRemaining = amount * (1.0 - minutesAgo / dia)
                totalIOB += iobRemaining
                
                // Activity is highest at peak time
                let peakTime = dia * 0.35 // Peak at 35% of DIA
                let activity = amount * exp(-pow(minutesAgo - peakTime, 2) / (2 * pow(dia * 0.2, 2)))
                totalActivity += activity
                
                bolusCount += 1
                trace("Bolus %{public}d: %{public}f units, %{public}f min ago, IOB: %{public}f", 
                      log: log, category: ConstantsLog.categoryRootView, type: .info,
                      bolusCount, amount, minutesAgo, iobRemaining)
            }
        }
        
        // IOB effect on BG (mg/dL per 5 min)
        let iobEffect = totalActivity * profile.sens / 12.0 // Divide by 12 for 5-minute intervals
        
        trace("Total IOB: %{public}f, Activity: %{public}f, Effect: %{public}f mg/dL per 5min", 
              log: log, category: ConstantsLog.categoryRootView, type: .info,
              totalIOB, totalActivity, iobEffect)
        
        return [
            "iob": totalIOB,
            "activity": totalActivity,
            "iobEffect": iobEffect
        ]
    }
    
    /// Calculate COB array for predictions
    private func calculateCOBArray(pumpHistory: [[String: Any]], profile: ProfileData) -> [String: Any] {
        // Simplified COB calculation
        var totalCOB = 0.0
        var carbActivity = 0.0
        
        let now = Date()
        let carbAbsorptionTime = 180.0 // 3 hours in minutes
        var carbCount = 0
        
        trace("Calculating COB with Carb Ratio: %{public}f", 
              log: log, category: ConstantsLog.categoryRootView, type: .info,
              profile.carb_ratio)
        
        for entry in pumpHistory {
            guard let type = entry["_type"] as? String,
                  type == "Meal Bolus",
                  let carbs = entry["carbs"] as? Int,
                  let timestampStr = entry["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampStr) else {
                continue
            }
            
            let minutesAgo = now.timeIntervalSince(timestamp) / 60.0
            
            if minutesAgo < carbAbsorptionTime {
                // Simple linear carb absorption
                let cobRemaining = Double(carbs) * (1.0 - minutesAgo / carbAbsorptionTime)
                totalCOB += cobRemaining
                
                // Carb activity peaks early
                let peakTime = carbAbsorptionTime * 0.25 // Peak at 25% of absorption time
                let activity = Double(carbs) * exp(-pow(minutesAgo - peakTime, 2) / (2 * pow(carbAbsorptionTime * 0.3, 2)))
                carbActivity += activity
                
                carbCount += 1
                trace("Carbs %{public}d: %{public}d g, %{public}f min ago, COB: %{public}f", 
                      log: log, category: ConstantsLog.categoryRootView, type: .info,
                      carbCount, carbs, minutesAgo, cobRemaining)
            }
        }
        
        // COB effect on BG (mg/dL per 5 min)
        let cobEffect = carbActivity / profile.carb_ratio * profile.sens / 12.0
        
        trace("Total COB: %{public}f, Activity: %{public}f, Effect: %{public}f mg/dL per 5min", 
              log: log, category: ConstantsLog.categoryRootView, type: .info,
              totalCOB, carbActivity, cobEffect)
        
        return [
            "cob": totalCOB,
            "activity": carbActivity,
            "cobEffect": cobEffect
        ]
    }
    */
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
                // Create bolus entry that matches what iAPS expects
                let bolusEntry: [String: Any] = [
                    "eventType": "Meal Bolus",  // Use "Meal Bolus" format that iAPS looks for
                    "created_at": timestamp,
                    "insulin": treatment.value,
                    "timestamp": timestamp,
                    "_type": "Bolus",
                    "amount": treatment.value
                ]
                pumpHistory.append(bolusEntry)
                
                trace("Added insulin bolus: %{public}f units at %{public}@", 
                      log: log, category: ConstantsLog.categoryRootView, type: .info,
                      treatment.value, timestamp)
                
            case .Carbs:
                // For MDI, we need to create a separate carb entry
                // iAPS expects carbs to be part of a "Meal Bolus" entry
                let carbEntry: [String: Any] = [
                    "eventType": "Meal Bolus",
                    "created_at": timestamp,
                    "carbs": Int(treatment.value),
                    "insulin": 0.0,  // No insulin with this entry, it's just carbs
                    "timestamp": timestamp
                ]
                pumpHistory.append(carbEntry)
                
                trace("Added carbs: %{public}f g at %{public}@", 
                      log: log, category: ConstantsLog.categoryRootView, type: .info,
                      treatment.value, timestamp)
                
            case .Basal:
                // For MDI users, basal might not be relevant, but keep for compatibility
                let tempBasalEntry: [String: Any] = [
                    "eventType": "Temp Basal",
                    "timestamp": timestamp,
                    "rate": treatment.value,
                    "duration": Int(treatment.valueSecondary > 0 ? treatment.valueSecondary : 30.0),
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
        
        // Get values from UserDefaults with correct keys
        // Check both old and new key names for compatibility
        let dia = userDefaults.object(forKey: "insulinActionDuration") as? Double ?? 
                  userDefaults.object(forKey: "insulinDuration") as? Double ?? 4.0
        let carbRatio = userDefaults.object(forKey: "carbsPerUnit") as? Double ??
                        userDefaults.object(forKey: "carbRatio") as? Double ?? 10.0
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
        // Create ISF profile in iAPS format
        let isfProfile: [String: Any] = [
            "sensitivities": [
                [
                    "sensitivity": sens,
                    "offset": 0,  // Start from midnight
                    "x": 0,
                    "i": 0
                ]
            ],
            "carb_ratios": [
                [
                    "ratio": carb_ratio,
                    "offset": 0,
                    "x": 0,
                    "i": 0
                ]
            ],
            "basalprofile": [
                [
                    "rate": basal_rate,  // 0 for MDI
                    "minutes": 0,
                    "i": 0
                ]
            ]
        ]
        
        var dict: [String: Any] = [
            "dia": dia,
            "carb_ratio": carb_ratio,
            "sens": sens,
            "max_iob": max_iob,
            "max_daily_basal": max_daily_basal,
            "max_basal_rate": max_basal_rate,
            "min_bg": min_bg,
            "max_bg": max_bg,
            "current_basal": basal_rate,
            // Add required fields for iAPS
            "curve": "rapid-acting",  // Default insulin curve
            "useCustomPeakTime": false,
            "basalprofile": [
                [
                    "rate": basal_rate,  // 0 for MDI
                    "minutes": 0,
                    "i": 0
                ]
            ],
            // Add ISF profile data
            "isfProfile": isfProfile,
            // Add additional fields that might be needed
            "min_5m_carbimpact": 8.0,  // Default minimum carb impact
            "maxCOB": 120,  // Maximum COB allowed
            "carbsPerHour": 20  // Default carb absorption rate
        ]
        
        if let insulinPeakTime = insulinPeakTime {
            dict["insulinPeakTime"] = insulinPeakTime
            dict["useCustomPeakTime"] = true
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