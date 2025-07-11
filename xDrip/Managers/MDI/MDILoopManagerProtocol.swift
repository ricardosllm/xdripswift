import Foundation

/// Errors that can occur in the MDI Loop system
enum MDIError: LocalizedError {
    
    // MARK: - Configuration Errors
    case missingSettings(String)
    case invalidSettings(String)
    case notEnabled
    
    // MARK: - Data Errors
    case insufficientData(String)
    case invalidGlucoseValue(Double)
    case staleData(minutesOld: Int)
    case noRecentReadings
    
    // MARK: - Calculation Errors
    case predictionFailed(String)
    case recommendationFailed(String)
    case iobCalculationFailed(String)
    case cobCalculationFailed(String)
    
    // MARK: - Notification Errors
    case notificationPermissionDenied
    case notificationFailed(String)
    
    // MARK: - System Errors
    case javascriptExecutionFailed(String)
    case memoryWarning
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingSettings(let setting):
            return "Missing required setting: \(setting)"
            
        case .invalidSettings(let setting):
            return "Invalid setting value: \(setting)"
            
        case .notEnabled:
            return "MDI Loop is not enabled"
            
        case .insufficientData(let detail):
            return "Insufficient data for calculation: \(detail)"
            
        case .invalidGlucoseValue(let value):
            return "Invalid glucose value: \(value)"
            
        case .staleData(let minutes):
            return "Glucose data is \(minutes) minutes old"
            
        case .noRecentReadings:
            return "No recent glucose readings available"
            
        case .predictionFailed(let reason):
            return "Prediction generation failed: \(reason)"
            
        case .recommendationFailed(let reason):
            return "Recommendation generation failed: \(reason)"
            
        case .iobCalculationFailed(let reason):
            return "IOB calculation failed: \(reason)"
            
        case .cobCalculationFailed(let reason):
            return "COB calculation failed: \(reason)"
            
        case .notificationPermissionDenied:
            return "Notification permission is required for MDI recommendations"
            
        case .notificationFailed(let reason):
            return "Failed to send notification: \(reason)"
            
        case .javascriptExecutionFailed(let reason):
            return "JavaScript execution failed: \(reason)"
            
        case .memoryWarning:
            return "Low memory warning - some features may be limited"
            
        case .unknownError(let error):
            return "Unknown error: \(error)"
        }
    }
    
    /// Whether this error should be shown to the user
    var shouldShowToUser: Bool {
        switch self {
        case .missingSettings, .invalidSettings, .notEnabled,
             .notificationPermissionDenied, .staleData:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error is critical and should stop the loop
    var isCritical: Bool {
        switch self {
        case .notEnabled, .missingSettings, .invalidSettings,
             .javascriptExecutionFailed, .memoryWarning:
            return true
        default:
            return false
        }
    }
}

/// Protocol defining the interface for MDI Loop Management
/// Following the Interface Segregation Principle (ISP) to keep interfaces focused
protocol MDILoopManagerProtocol: AnyObject {
    
    /// Check if MDI Loop is enabled
    var isEnabled: Bool { get }
    
    /// Start the MDI loop monitoring
    func startLoop()
    
    /// Stop the MDI loop monitoring
    func stopLoop()
    
    /// Run a single loop cycle to check if recommendations are needed
    func runLoopCycle()
    
    /// Get the last recommendation made (if any)
    var lastRecommendation: MDIRecommendation? { get }
    
    /// Check if a recommendation can be made now (respecting time limits)
    func canMakeRecommendation() -> Bool
}

/// Protocol for MDI loop delegate callbacks
protocol MDILoopManagerDelegate: AnyObject {
    
    /// Called when a new recommendation is generated
    func mdiLoopManager(_ manager: MDILoopManagerProtocol, didGenerateRecommendation recommendation: MDIRecommendation)
    
    /// Called when the loop status changes
    func mdiLoopManager(_ manager: MDILoopManagerProtocol, didChangeStatus isRunning: Bool)
    
    /// Called when an error occurs
    func mdiLoopManager(_ manager: MDILoopManagerProtocol, didEncounterError error: MDIError)
}

/// Basic data structure for MDI recommendations
struct MDIRecommendation {
    let id: UUID
    let timestamp: Date
    let type: MDIRecommendationType
    let dose: Double?
    let carbs: Int?
    let reason: String
    let urgency: MDIUrgencyLevel
    let expiresAt: Date
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         type: MDIRecommendationType,
         dose: Double? = nil,
         carbs: Int? = nil,
         reason: String,
         urgency: MDIUrgencyLevel,
         expiresAt: Date) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.dose = dose
        self.carbs = carbs
        self.reason = reason
        self.urgency = urgency
        self.expiresAt = expiresAt
    }
}

enum MDIRecommendationType: CustomStringConvertible {
    case correctionBolus
    case mealBolus
    case carbsNeeded
    case basalAdjustment
    case combinedBolus // correction + meal
    
    var description: String {
        switch self {
        case .correctionBolus:
            return "Correction"
        case .mealBolus:
            return "Meal"
        case .carbsNeeded:
            return "Carbs"
        case .basalAdjustment:
            return "Basal"
        case .combinedBolus:
            return "Combined"
        }
    }
}

enum MDIUrgencyLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: MDIUrgencyLevel, rhs: MDIUrgencyLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}