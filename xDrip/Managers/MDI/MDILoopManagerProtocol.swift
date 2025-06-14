import Foundation

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
    func mdiLoopManager(_ manager: MDILoopManagerProtocol, didEncounterError error: Error)
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

enum MDIRecommendationType {
    case correctionBolus
    case mealBolus
    case carbsNeeded
    case basalAdjustment
    case combinedBolus // correction + meal
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