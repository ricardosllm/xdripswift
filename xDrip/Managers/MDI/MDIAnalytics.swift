import Foundation
import os.log

/// Simple analytics tracking for MDI feature usage
/// This helps understand how users interact with MDI features
final class MDIAnalytics {
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = MDIAnalytics()
    
    /// Log for analytics
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "MDIAnalytics")
    
    /// Analytics event types
    enum Event: String {
        // Feature usage
        case loopEnabled = "mdi_loop_enabled"
        case loopDisabled = "mdi_loop_disabled"
        case loopCycleRun = "mdi_loop_cycle_run"
        
        // Recommendations
        case recommendationGenerated = "mdi_recommendation_generated"
        case recommendationAccepted = "mdi_recommendation_accepted"
        case recommendationDismissed = "mdi_recommendation_dismissed"
        case recommendationSnoozed = "mdi_recommendation_snoozed"
        case recommendationExpired = "mdi_recommendation_expired"
        
        // Notifications
        case notificationSent = "mdi_notification_sent"
        case notificationInteracted = "mdi_notification_interacted"
        
        // Settings
        case settingsChanged = "mdi_settings_changed"
        case basalUpdated = "mdi_basal_updated"
        
        // UI interactions
        case historyViewed = "mdi_history_viewed"
        case helpViewed = "mdi_help_viewed"
        
        // Errors
        case errorOccurred = "mdi_error_occurred"
    }
    
    // MARK: - Private Properties
    
    /// Storage for analytics data
    private let analyticsKey = "MDIAnalyticsData"
    
    /// Current session start time
    private var sessionStartTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        sessionStartTime = Date()
    }
    
    // MARK: - Public Methods
    
    /// Track an event
    func track(_ event: Event, parameters: [String: Any]? = nil) {
        var eventData: [String: Any] = [
            "event": event.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "session_duration": sessionDuration()
        ]
        
        // Add custom parameters
        if let parameters = parameters {
            eventData.merge(parameters) { _, new in new }
        }
        
        // Log the event
        os_log("Analytics event: %{public}@ with data: %{public}@", 
               log: log, 
               type: .info, 
               event.rawValue, 
               String(describing: eventData))
        
        // Store the event
        storeEvent(eventData)
        
        // Update summary statistics
        updateStatistics(for: event)
    }
    
    /// Get analytics summary
    func getAnalyticsSummary() -> AnalyticsSummary {
        let statistics = loadStatistics()
        
        return AnalyticsSummary(
            totalLoopCycles: statistics["total_loop_cycles"] as? Int ?? 0,
            totalRecommendations: statistics["total_recommendations"] as? Int ?? 0,
            acceptedRecommendations: statistics["accepted_recommendations"] as? Int ?? 0,
            dismissedRecommendations: statistics["dismissed_recommendations"] as? Int ?? 0,
            snoozedRecommendations: statistics["snoozed_recommendations"] as? Int ?? 0,
            totalNotifications: statistics["total_notifications"] as? Int ?? 0,
            featureEnabledTime: statistics["feature_enabled_time"] as? TimeInterval ?? 0,
            lastActiveDate: statistics["last_active_date"] as? Date
        )
    }
    
    /// Clear all analytics data (for privacy)
    func clearAnalyticsData() {
        UserDefaults.standard.removeObject(forKey: analyticsKey)
        UserDefaults.standard.removeObject(forKey: "\(analyticsKey)_statistics")
        os_log("Analytics data cleared", log: log, type: .info)
    }
    
    // MARK: - Private Methods
    
    private func sessionDuration() -> TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    private func storeEvent(_ eventData: [String: Any]) {
        // For now, just store the last 100 events in UserDefaults
        // In production, this would send to a proper analytics service
        
        var events = UserDefaults.standard.object(forKey: analyticsKey) as? [[String: Any]] ?? []
        events.append(eventData)
        
        // Keep only last 100 events
        if events.count > 100 {
            events = Array(events.suffix(100))
        }
        
        UserDefaults.standard.set(events, forKey: analyticsKey)
    }
    
    private func updateStatistics(for event: Event) {
        var statistics = loadStatistics()
        
        switch event {
        case .loopCycleRun:
            statistics["total_loop_cycles"] = (statistics["total_loop_cycles"] as? Int ?? 0) + 1
            
        case .recommendationGenerated:
            statistics["total_recommendations"] = (statistics["total_recommendations"] as? Int ?? 0) + 1
            
        case .recommendationAccepted:
            statistics["accepted_recommendations"] = (statistics["accepted_recommendations"] as? Int ?? 0) + 1
            
        case .recommendationDismissed:
            statistics["dismissed_recommendations"] = (statistics["dismissed_recommendations"] as? Int ?? 0) + 1
            
        case .recommendationSnoozed:
            statistics["snoozed_recommendations"] = (statistics["snoozed_recommendations"] as? Int ?? 0) + 1
            
        case .notificationSent:
            statistics["total_notifications"] = (statistics["total_notifications"] as? Int ?? 0) + 1
            
        case .loopEnabled:
            statistics["loop_enabled_count"] = (statistics["loop_enabled_count"] as? Int ?? 0) + 1
            statistics["last_enabled_date"] = Date()
            
        case .loopDisabled:
            // Track total time enabled
            if let lastEnabled = statistics["last_enabled_date"] as? Date {
                let enabledDuration = Date().timeIntervalSince(lastEnabled)
                statistics["feature_enabled_time"] = (statistics["feature_enabled_time"] as? TimeInterval ?? 0) + enabledDuration
            }
            
        default:
            break
        }
        
        // Always update last active date
        statistics["last_active_date"] = Date()
        
        // Save statistics
        UserDefaults.standard.set(statistics, forKey: "\(analyticsKey)_statistics")
    }
    
    private func loadStatistics() -> [String: Any] {
        return UserDefaults.standard.object(forKey: "\(analyticsKey)_statistics") as? [String: Any] ?? [:]
    }
}

// MARK: - Analytics Summary

struct AnalyticsSummary {
    let totalLoopCycles: Int
    let totalRecommendations: Int
    let acceptedRecommendations: Int
    let dismissedRecommendations: Int
    let snoozedRecommendations: Int
    let totalNotifications: Int
    let featureEnabledTime: TimeInterval
    let lastActiveDate: Date?
    
    var acceptanceRate: Double {
        guard totalRecommendations > 0 else { return 0 }
        return Double(acceptedRecommendations) / Double(totalRecommendations)
    }
    
    var dismissalRate: Double {
        guard totalRecommendations > 0 else { return 0 }
        return Double(dismissedRecommendations) / Double(totalRecommendations)
    }
    
    var formattedEnabledTime: String {
        let hours = Int(featureEnabledTime / 3600)
        let minutes = Int((featureEnabledTime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}