import Foundation
import CoreData

extension MDIRecommendationHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MDIRecommendationHistory> {
        return NSFetchRequest<MDIRecommendationHistory>(entityName: "MDIRecommendationHistory")
    }

    // MARK: - Basic Properties
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var recommendationType: String?
    @NSManaged public var recommendedDose: Double
    @NSManaged public var recommendedCarbs: Double
    @NSManaged public var reason: String?
    @NSManaged public var urgencyLevel: Int16
    @NSManaged public var expiresAt: Date?
    
    // MARK: - Status Properties
    @NSManaged public var status: String?
    @NSManaged public var actionTakenAt: Date?
    @NSManaged public var snoozeUntil: Date?
    
    // MARK: - Actual Values (if different from recommended)
    @NSManaged public var actualDoseTaken: Double
    @NSManaged public var actualCarbsTaken: Double
    @NSManaged public var notes: String?
    
    // MARK: - Context Data (for analysis)
    @NSManaged public var glucoseAtTime: Double
    @NSManaged public var predictedGlucose: Double
    @NSManaged public var iobAtTime: Double
    @NSManaged public var cobAtTime: Double
    @NSManaged public var trendArrow: String?
}

// MARK: - Fetch Helpers

extension MDIRecommendationHistory {
    
    /// Fetch all recommendations in date range
    static func fetchRecommendations(from startDate: Date,
                                   to endDate: Date,
                                   managedObjectContext: NSManagedObjectContext) -> [MDIRecommendationHistory] {
        let request: NSFetchRequest<MDIRecommendationHistory> = fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try managedObjectContext.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch pending recommendations
    static func fetchPendingRecommendations(managedObjectContext: NSManagedObjectContext) -> [MDIRecommendationHistory] {
        let request: NSFetchRequest<MDIRecommendationHistory> = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ AND expiresAt > %@", 
                                      RecommendationStatus.pending.stringValue,
                                      Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try managedObjectContext.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch accepted recommendations for analysis
    static func fetchAcceptedRecommendations(limit: Int = 100,
                                           managedObjectContext: NSManagedObjectContext) -> [MDIRecommendationHistory] {
        let request: NSFetchRequest<MDIRecommendationHistory> = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ OR status == %@",
                                      RecommendationStatus.accepted.stringValue,
                                      RecommendationStatus.modified.stringValue)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try managedObjectContext.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Get statistics for recommendations
    static func getStatistics(for days: Int = 30,
                            managedObjectContext: NSManagedObjectContext) -> RecommendationStatistics {
        let startDate = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let allRecommendations = fetchRecommendations(from: startDate,
                                                    to: Date(),
                                                    managedObjectContext: managedObjectContext)
        
        let total = allRecommendations.count
        let accepted = allRecommendations.filter { $0.status == RecommendationStatus.accepted.stringValue }.count
        let dismissed = allRecommendations.filter { $0.status == RecommendationStatus.dismissed.stringValue }.count
        let snoozed = allRecommendations.filter { $0.status == RecommendationStatus.snoozed.stringValue }.count
        let expired = allRecommendations.filter { $0.status == RecommendationStatus.expired.stringValue }.count
        
        let acceptanceRate = total > 0 ? Double(accepted) / Double(total) : 0
        
        return RecommendationStatistics(
            totalRecommendations: total,
            acceptedCount: accepted,
            dismissedCount: dismissed,
            snoozedCount: snoozed,
            expiredCount: expired,
            acceptanceRate: acceptanceRate
        )
    }
}

/// Statistics structure for recommendations
struct RecommendationStatistics {
    let totalRecommendations: Int
    let acceptedCount: Int
    let dismissedCount: Int
    let snoozedCount: Int
    let expiredCount: Int
    let acceptanceRate: Double
}