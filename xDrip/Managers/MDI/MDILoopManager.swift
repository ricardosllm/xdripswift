import Foundation
import os.log

/// Main implementation of MDI Loop Manager
/// Follows Single Responsibility Principle - manages the loop cycle only
final class MDILoopManager: NSObject, MDILoopManagerProtocol {
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = MDILoopManager()
    
    /// Delegate for callbacks
    weak var delegate: MDILoopManagerDelegate?
    
    /// Timer for loop cycles
    private var loopTimer: Timer?
    
    /// Notification manager
    private let notificationManager = MDINotificationManager.shared
    
    /// Last recommendation made
    private(set) var lastRecommendation: MDIRecommendation?
    
    /// Last time a recommendation was made
    private var lastRecommendationTime: Date?
    
    /// Log for MDI operations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// Check if MDI Loop is enabled
    var isEnabled: Bool {
        return UserDefaults.standard.mdiLoopEnabled
    }
    
    /// Check if loop is currently running
    private(set) var isRunning: Bool = false
    
    /// Loop cycle interval (5 minutes)
    private let loopCycleInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Dependencies (Dependency Injection)
    
    private var coreDataManager: CoreDataManager?
    private var bgReadingsAccessor: BgReadingsAccessor?
    private var treatmentEntryAccessor: TreatmentEntryAccessor?
    private var recommendationEngine: MDIRecommendationEngine?
    
    // MARK: - Initialization
    
    override private init() {
        super.init()
    }
    
    /// Configure with core data manager
    func configure(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        self.recommendationEngine = MDIRecommendationEngine(coreDataManager: coreDataManager)
        
        // Configure notification manager
        notificationManager.configure(coreDataManager: coreDataManager)
    }
    
    // MARK: - Public Methods
    
    /// Start the MDI loop monitoring
    func startLoop() {
        guard isEnabled else {
            os_log("MDI Loop is disabled in settings", log: log, type: .info)
            return
        }
        
        guard !isRunning else {
            os_log("MDI Loop is already running", log: log, type: .info)
            return
        }
        
        isRunning = true
        
        // Request notification permissions if needed
        notificationManager.requestNotificationPermission { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                os_log("Notification permissions granted for MDI Loop", log: self.log, type: .info)
            } else {
                os_log("Notification permissions denied for MDI Loop", log: self.log, type: .error)
            }
        }
        
        // Run initial cycle
        runLoopCycle()
        
        // Schedule recurring cycles
        loopTimer = Timer.scheduledTimer(withTimeInterval: loopCycleInterval, repeats: true) { [weak self] _ in
            self?.runLoopCycle()
        }
        
        os_log("MDI Loop started", log: log, type: .info)
        delegate?.mdiLoopManager(self, didChangeStatus: true)
    }
    
    /// Stop the MDI loop monitoring
    func stopLoop() {
        loopTimer?.invalidate()
        loopTimer = nil
        isRunning = false
        
        os_log("MDI Loop stopped", log: log, type: .info)
        delegate?.mdiLoopManager(self, didChangeStatus: false)
    }
    
    /// Run a single loop cycle to check if recommendations are needed
    func runLoopCycle() {
        do {
            // Check if enabled
            guard isEnabled else {
                throw MDIError.notEnabled
            }
            
            os_log("Running MDI loop cycle", log: log, type: .debug)
            
            // Get latest glucose reading
            guard let bgReadingsAccessor = bgReadingsAccessor else {
                throw MDIError.missingSettings("bgReadingsAccessor")
            }
            
            guard let latestReading = bgReadingsAccessor.getLatestBgReadings(
                limit: 1, 
                fromDate: nil, 
                forSensor: nil, 
                ignoreRawData: true, 
                ignoreCalculatedValue: false
            ).first else {
                throw MDIError.noRecentReadings
            }
            
            // Validate glucose value
            let glucoseValue = latestReading.calculatedValue
            guard glucoseValue > 0 && glucoseValue < 1000 else {
                throw MDIError.invalidGlucoseValue(glucoseValue)
            }
            
            // Check data freshness
            let minutesOld = Int(-latestReading.timeStamp.timeIntervalSinceNow / 60)
            if minutesOld > 10 {
                throw MDIError.staleData(minutesOld: minutesOld)
            }
            
            // Check if we can make a recommendation based on time limits
            guard canMakeRecommendation() else {
                os_log("Too soon to make another recommendation", log: log, type: .debug)
                return
            }
            
            // Get recent readings for trend analysis (last 30 minutes)
            let recentReadings = bgReadingsAccessor.getLatestBgReadings(
                limit: 10,
                fromDate: Date().addingTimeInterval(-1800), // 30 minutes
                forSensor: nil,
                ignoreRawData: true,
                ignoreCalculatedValue: false
            )
            
            // Ensure we have enough data for analysis
            guard recentReadings.count >= 3 else {
                throw MDIError.insufficientData("Need at least 3 readings for trend analysis")
            }
            
            // Analyze and generate recommendation if needed
            if let recommendation = analyzeAndGenerateRecommendation(
                currentReading: latestReading,
                recentReadings: Array(recentReadings)
            ) {
                lastRecommendation = recommendation
                lastRecommendationTime = Date()
                
                os_log("Generated MDI recommendation: %{public}@", log: log, type: .info, recommendation.reason)
                
                // Send notification
                notificationManager.sendNotification(for: recommendation)
                
                // Notify delegate
                delegate?.mdiLoopManager(self, didGenerateRecommendation: recommendation)
            }
            
        } catch let error as MDIError {
            handleError(error)
        } catch {
            handleError(MDIError.unknownError(error.localizedDescription))
        }
    }
    
    /// Handle MDI errors appropriately
    private func handleError(_ error: MDIError) {
        os_log("MDI Loop error: %{public}@", log: log, type: .error, error.localizedDescription)
        
        // Notify delegate of errors that should be shown to user
        if error.shouldShowToUser {
            delegate?.mdiLoopManager(self, didEncounterError: error)
        }
        
        // Stop loop if critical error
        if error.isCritical {
            stopLoop()
        }
    }
    
    /// Check if a recommendation can be made now (respecting time limits)
    func canMakeRecommendation() -> Bool {
        guard let lastTime = lastRecommendationTime else {
            // No previous recommendation
            return true
        }
        
        // For MDI users, we'll use a reasonable minimum interval of 15 minutes
        // to avoid notification fatigue
        let minInterval: TimeInterval = 900 // 15 minutes
        let timeSinceLastRecommendation = Date().timeIntervalSince(lastTime)
        
        return timeSinceLastRecommendation >= minInterval
    }
    
    // MARK: - Private Methods
    
    /// Analyze readings and generate recommendation if needed
    private func analyzeAndGenerateRecommendation(
        currentReading: BgReading,
        recentReadings: [BgReading]
    ) -> MDIRecommendation? {
        
        guard let recommendationEngine = recommendationEngine,
              let treatmentEntryAccessor = treatmentEntryAccessor else {
            os_log("Recommendation engine or treatment accessor not configured", log: log, type: .error)
            return nil
        }
        
        // Get recent treatments for IOB/COB calculation
        let treatments = treatmentEntryAccessor.getLatestTreatments(
            limit: 100,
            fromDate: Date().addingTimeInterval(-24 * 3600) // Last 24 hours
        )
        
        // Get more BG readings for better predictions (last 4 hours)
        let extendedReadings = bgReadingsAccessor?.getLatestBgReadings(
            limit: 48,
            fromDate: Date().addingTimeInterval(-4 * 3600),
            forSensor: nil,
            ignoreRawData: false,
            ignoreCalculatedValue: false
        ) ?? recentReadings
        
        // Generate recommendation using the engine
        guard let engineRecommendation = recommendationEngine.generateRecommendation(
            bgReadings: extendedReadings,
            treatments: treatments,
            pendingCarbs: nil as Double? // TODO: Add pending carbs from UI when available
        ) else {
            os_log("Recommendation engine did not generate a recommendation", log: log, type: .debug)
            return nil
        }
        
        // Convert engine recommendation to MDIRecommendation
        let (title, _) = engineRecommendation.formatForNotification()
        
        // Map urgency
        let urgency: MDIUrgencyLevel
        switch engineRecommendation.urgency {
        case .urgent:
            urgency = .high
        case .normal:
            urgency = .medium
        case .optional:
            urgency = .low
        }
        
        // Map recommendation type
        let recommendationType: MDIRecommendationType
        let dose: Double?
        let carbs: Int?
        
        switch engineRecommendation.type {
        case .correction:
            recommendationType = .correctionBolus
            dose = getRecommendedUnits(from: engineRecommendation.type)
            carbs = nil
        case .meal(_, let mealCarbs, _):
            recommendationType = .mealBolus
            dose = getRecommendedUnits(from: engineRecommendation.type)
            carbs = Int(mealCarbs)
        case .both:
            recommendationType = .combinedBolus
            dose = getRecommendedUnits(from: engineRecommendation.type)
            if case .both(_, _, let mealCarbs, _) = engineRecommendation.type {
                carbs = Int(mealCarbs)
            } else {
                carbs = nil
            }
        case .none:
            // No recommendation needed
            return nil
        }
        
        // Create MDI recommendation
        let recommendation = MDIRecommendation(
            id: engineRecommendation.id,
            timestamp: engineRecommendation.timestamp,
            type: recommendationType,
            dose: dose,
            carbs: carbs,
            reason: title,
            urgency: urgency,
            expiresAt: engineRecommendation.expires
        )
        
        return recommendation
    }
    
    /// Extract recommended units from recommendation type
    private func getRecommendedUnits(from type: MDIRecommendationEngine.RecommendationType) -> Double {
        switch type {
        case .correction(let units, _):
            return units
        case .meal(let units, _, _):
            return units
        case .both(let correctionUnits, let mealUnits, _, _):
            return correctionUnits + mealUnits
        case .none(_):
            return 0
        }
    }
    
    /// ORIGINAL METHOD - Keeping for reference but not using
    private func analyzeAndGenerateRecommendation_OLD(
        currentReading: BgReading,
        recentReadings: [BgReading]
    ) -> MDIRecommendation? {
        
        // Get current glucose value
        let currentGlucose = currentReading.calculatedValue
        
        // Get user settings
        let highThreshold = UserDefaults.standard.highMarkValue
        let urgentHighThreshold = UserDefaults.standard.urgentHighMarkValue
        let lowThreshold = UserDefaults.standard.lowMarkValue
        let urgentLowThreshold = UserDefaults.standard.urgentLowMarkValue
        let notificationThreshold = UserDefaults.standard.mdiNotificationUrgencyThreshold
        
        // Check for urgent low - always notify regardless of threshold setting
        if currentGlucose <= urgentLowThreshold {
            return MDIRecommendation(
                type: .carbsNeeded,
                carbs: 15, // Standard 15g for urgent low
                reason: "Glucose is urgently low at \(Int(currentGlucose)) mg/dL",
                urgency: .critical,
                expiresAt: Date().addingTimeInterval(300) // 5 minutes
            )
        }
        
        // For high glucose, use simple calculation for now
        // TODO: Use advanced bolus calculator when MDIBolusCalculator is added to project
        if currentGlucose >= urgentHighThreshold {
            return MDIRecommendation(
                type: .correctionBolus,
                dose: calculateSimpleCorrectionDose(glucose: currentGlucose),
                reason: "Glucose is urgently high at \(Int(currentGlucose)) mg/dL",
                urgency: .critical,
                expiresAt: Date().addingTimeInterval(900) // 15 minutes
            )
        }
        
        // Check notification threshold setting
        if notificationThreshold == "urgent" {
            // Only urgent notifications
            return nil
        }
        
        // Check for low with falling trend
        let trend = calculateTrend(from: recentReadings)
        if currentGlucose <= lowThreshold && trend < 0 {
            return MDIRecommendation(
                type: .carbsNeeded,
                carbs: 10,
                reason: "Glucose is low and falling",
                urgency: .high,
                expiresAt: Date().addingTimeInterval(600) // 10 minutes
            )
        }
        
        // If notification threshold is "any", we could add more recommendations here
        // For now, we'll keep it simple
        
        return nil
    }
    
    /// Calculate simple correction dose (temporary - will be replaced by MDIBolusCalculator)
    private func calculateSimpleCorrectionDose(glucose: Double) -> Double {
        let targetGlucose = UserDefaults.standard.targetMarkValueInUserChosenUnit
        let isf = UserDefaults.standard.insulinSensitivityMgDl
        
        let correction = (glucose - targetGlucose) / isf
        
        // Round to nearest 0.5 units
        let roundedCorrection = round(correction * 2) / 2
        
        // For MDI, we let users decide their own limits
        return max(roundedCorrection, 0)
    }
    
    /// Calculate trend from recent readings
    private func calculateTrend(from readings: [BgReading]) -> Double {
        guard readings.count >= 3 else { return 0 }
        
        // Simple linear regression on recent points
        let sortedReadings = readings.sorted { $0.timeStamp < $1.timeStamp }
        let firstReading = sortedReadings.first!
        let lastReading = sortedReadings.last!
        
        let timeDiff = lastReading.timeStamp.timeIntervalSince(firstReading.timeStamp) / 60 // minutes
        guard timeDiff > 0 else { return 0 }
        
        let glucoseDiff = lastReading.calculatedValue - firstReading.calculatedValue
        
        return glucoseDiff / timeDiff // mg/dL per minute
    }
}