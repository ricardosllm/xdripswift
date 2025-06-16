import Foundation
import CoreData

@objc(MDIRecommendationHistory)
public class MDIRecommendationHistory: NSManagedObject {
    
    /// Initialize with recommendation data
    convenience init(recommendation: MDIRecommendation,
                     context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.id = recommendation.id
        self.timestamp = recommendation.timestamp
        self.recommendationType = recommendation.type.description
        self.recommendedDose = recommendation.dose ?? 0
        self.recommendedCarbs = Double(recommendation.carbs ?? 0)
        self.reason = recommendation.reason
        self.urgencyLevel = Int16(recommendation.urgency.rawValue)
        self.expiresAt = recommendation.expiresAt
        self.status = RecommendationStatus.pending.stringValue
        self.createdAt = Date()
    }
    
    /// Update status when user takes action
    func updateStatus(_ newStatus: RecommendationStatus, actionTaken: Date = Date()) {
        self.status = newStatus.stringValue
        self.actionTakenAt = actionTaken
        
        // If accepted, store the actual values taken
        if newStatus == .accepted {
            self.actualDoseTaken = self.recommendedDose
            self.actualCarbsTaken = self.recommendedCarbs
        }
    }
    
    /// Update with actual values if different from recommended
    func updateActualValues(dose: Double? = nil, carbs: Double? = nil) {
        if let dose = dose {
            self.actualDoseTaken = dose
        }
        if let carbs = carbs {
            self.actualCarbsTaken = carbs
        }
    }
    
    /// Check if recommendation is still valid
    var isValid: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt > Date() && status == RecommendationStatus.pending.stringValue
    }
    
    /// Get age of recommendation
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp ?? Date())
    }
    
    /// Get formatted description for display
    var displayDescription: String {
        var description = ""
        
        if let type = recommendationType {
            description += type + ": "
        }
        
        if recommendedDose > 0 {
            description += String(format: "%.1fU", recommendedDose)
        }
        
        if recommendedCarbs > 0 {
            if !description.isEmpty { description += ", " }
            description += String(format: "%.0fg carbs", recommendedCarbs)
        }
        
        return description
    }
}

/// Status of a recommendation
@objc enum RecommendationStatus: Int16 {
    case pending = 0
    case accepted = 1
    case dismissed = 2
    case snoozed = 3
    case expired = 4
    case modified = 5 // User accepted but with different values
    
    var stringValue: String {
        switch self {
        case .pending: return "pending"
        case .accepted: return "accepted"
        case .dismissed: return "dismissed"
        case .snoozed: return "snoozed"
        case .expired: return "expired"
        case .modified: return "modified"
        }
    }
    
    init?(stringValue: String) {
        switch stringValue {
        case "pending": self = .pending
        case "accepted": self = .accepted
        case "dismissed": self = .dismissed
        case "snoozed": self = .snoozed
        case "expired": self = .expired
        case "modified": self = .modified
        default: return nil
        }
    }
}