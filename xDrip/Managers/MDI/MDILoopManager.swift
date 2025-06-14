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
    
    /// Last recommendation made
    private(set) var lastRecommendation: MDIRecommendation?
    
    /// Last time a recommendation was made
    private var lastRecommendationTime: Date?
    
    /// Log for MDI operations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "MDILoopManager")
    
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
    
    // MARK: - Initialization
    
    override private init() {
        super.init()
    }
    
    /// Configure with core data manager
    func configure(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
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
        guard isEnabled else { return }
        
        os_log("Running MDI loop cycle", log: log, type: .debug)
        
        // Get latest glucose reading
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            os_log("BgReadingsAccessor not configured", log: log, type: .error)
            return
        }
        
        guard let latestReading = bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).first else {
            os_log("No glucose reading available", log: log, type: .info)
            return
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
        
        // Analyze and generate recommendation if needed
        if let recommendation = analyzeAndGenerateRecommendation(
            currentReading: latestReading,
            recentReadings: recentReadings
        ) {
            lastRecommendation = recommendation
            lastRecommendationTime = Date()
            
            os_log("Generated MDI recommendation: %{public}@", log: log, type: .info, recommendation.reason)
            delegate?.mdiLoopManager(self, didGenerateRecommendation: recommendation)
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
        
        // Get current glucose value
        let currentGlucose = currentReading.calculatedValue
        
        // Calculate trend if we have enough readings
        let trend = calculateTrend(from: recentReadings)
        
        // Get user settings
        let highThreshold = UserDefaults.standard.highMarkValue
        let urgentHighThreshold = UserDefaults.standard.urgentHighMarkValue
        let lowThreshold = UserDefaults.standard.lowMarkValue
        let urgentLowThreshold = UserDefaults.standard.urgentLowMarkValue
        let notificationThreshold = UserDefaults.standard.mdiNotificationUrgencyThreshold
        
        // Simple decision logic for now (will be enhanced with MDIBolusCalculator)
        
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
        
        // Check for urgent high
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
            // Only urgent notifications, we've already checked those above
            return nil
        }
        
        // Check for high with rising trend
        if currentGlucose >= highThreshold && trend > 0 {
            return MDIRecommendation(
                type: .correctionBolus,
                dose: calculateSimpleCorrectionDose(glucose: currentGlucose),
                reason: "Glucose is high and rising",
                urgency: .high,
                expiresAt: Date().addingTimeInterval(1800) // 30 minutes
            )
        }
        
        // Check for low with falling trend
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