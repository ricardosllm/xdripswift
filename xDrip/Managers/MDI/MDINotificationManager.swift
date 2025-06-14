import Foundation
import UserNotifications
import os.log

/// Manages notifications for MDI Loop recommendations
/// Follows Single Responsibility Principle - only handles notification logic
final class MDINotificationManager: NSObject {
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = MDINotificationManager()
    
    /// Log for notification operations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    /// Notification category identifier
    private let mdiCategoryIdentifier = "MDI_RECOMMENDATION"
    
    /// Notification actions
    private let acceptActionIdentifier = "ACCEPT_MDI"
    private let snoozeActionIdentifier = "SNOOZE_MDI"
    private let dismissActionIdentifier = "DISMISS_MDI"
    
    // MARK: - Initialization
    
    override private init() {
        super.init()
        setupNotificationCategories()
    }
    
    // MARK: - Public Methods
    
    /// Request notification permissions if not already granted
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                os_log("Error requesting notification permission: %{public}@", log: self.log, type: .error, error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    /// Send a notification for an MDI recommendation
    func sendNotification(for recommendation: MDIRecommendation) {
        guard UserDefaults.standard.mdiNotificationsEnabled else {
            os_log("MDI notifications are disabled", log: self.log, type: .info)
            return
        }
        
        // Create notification content
        let content = createNotificationContent(for: recommendation)
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: recommendation.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                os_log("Error scheduling MDI notification: %{public}@", log: self.log, type: .error, error.localizedDescription)
            } else {
                os_log("MDI notification scheduled successfully", log: self.log, type: .info)
            }
        }
    }
    
    /// Cancel a specific notification
    func cancelNotification(with identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    /// Cancel all MDI notifications
    func cancelAllNotifications() {
        // Get all pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let mdiIdentifiers = requests
                .filter { $0.content.categoryIdentifier == self.mdiCategoryIdentifier }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: mdiIdentifiers)
        }
        
        // Get all delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let mdiIdentifiers = notifications
                .filter { $0.request.content.categoryIdentifier == self.mdiCategoryIdentifier }
                .map { $0.request.identifier }
            
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: mdiIdentifiers)
        }
    }
    
    // MARK: - Private Methods
    
    /// Setup notification categories and actions
    private func setupNotificationCategories() {
        // Define actions
        let acceptAction = UNNotificationAction(
            identifier: acceptActionIdentifier,
            title: "Log Injection",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze 15 min",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: dismissActionIdentifier,
            title: "Dismiss",
            options: [.destructive]
        )
        
        // Define category
        let mdiCategory = UNNotificationCategory(
            identifier: mdiCategoryIdentifier,
            actions: [acceptAction, snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([mdiCategory])
    }
    
    /// Create notification content for a recommendation
    private func createNotificationContent(for recommendation: MDIRecommendation) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // Set basic content
        content.title = getNotificationTitle(for: recommendation)
        content.body = getNotificationBody(for: recommendation)
        content.categoryIdentifier = mdiCategoryIdentifier
        
        // Set sound if enabled
        if UserDefaults.standard.mdiNotificationSoundEnabled {
            content.sound = getNotificationSound(for: recommendation.urgency)
        }
        
        // Add user info for handling
        content.userInfo = [
            "recommendationId": recommendation.id.uuidString,
            "recommendationType": String(describing: recommendation.type),
            "urgency": recommendation.urgency.rawValue
        ]
        
        // Set thread identifier for grouping
        content.threadIdentifier = "MDI_RECOMMENDATIONS"
        
        // Add subtitle with prediction impact if enabled
        if UserDefaults.standard.mdiShowPredictionImpact {
            content.subtitle = getPredictionImpactText(for: recommendation)
        }
        
        return content
    }
    
    /// Get notification title based on recommendation type
    private func getNotificationTitle(for recommendation: MDIRecommendation) -> String {
        switch recommendation.type {
        case .correctionBolus:
            return "💉 Correction Recommended"
        case .mealBolus:
            return "🍽 Meal Bolus Recommended"
        case .carbsNeeded:
            return "🍬 Carbs Needed"
        case .basalAdjustment:
            return "⚡️ Basal Adjustment"
        case .combinedBolus:
            return "💉 Bolus Recommended"
        }
    }
    
    /// Get notification body based on recommendation
    private func getNotificationBody(for recommendation: MDIRecommendation) -> String {
        var body = recommendation.reason
        
        // Add specific recommendation details
        switch recommendation.type {
        case .correctionBolus, .mealBolus, .combinedBolus:
            if let dose = recommendation.dose {
                body += "\nRecommended: \(dose) units"
            }
        case .carbsNeeded:
            if let carbs = recommendation.carbs {
                body += "\nRecommended: \(carbs)g carbs"
            }
        case .basalAdjustment:
            body += "\nCheck basal settings"
        }
        
        return body
    }
    
    /// Get prediction impact text
    private func getPredictionImpactText(for recommendation: MDIRecommendation) -> String {
        // This will be enhanced when we implement prediction impact calculations
        switch recommendation.type {
        case .correctionBolus, .combinedBolus:
            return "Predicted to return to range"
        case .carbsNeeded:
            return "Prevent low glucose"
        case .mealBolus:
            return "Cover meal carbs"
        case .basalAdjustment:
            return "Improve overall control"
        }
    }
    
    /// Get notification sound based on urgency
    private func getNotificationSound(for urgency: MDIUrgencyLevel) -> UNNotificationSound {
        switch urgency {
        case .critical:
            // Use the app's alarm sound for critical alerts
            return UNNotificationSound(named: UNNotificationSoundName("alarm_high.mp3"))
        case .high:
            return .defaultCritical
        case .medium:
            return .default
        case .low:
            return .default
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MDINotificationManager: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Check if this is an MDI notification
        if notification.request.content.categoryIdentifier == mdiCategoryIdentifier {
            // Show notification even when app is in foreground
            completionHandler([.alert, .sound, .badge])
        } else {
            completionHandler([])
        }
    }
    
    /// Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // Check if this is an MDI notification
        guard response.notification.request.content.categoryIdentifier == mdiCategoryIdentifier else {
            completionHandler()
            return
        }
        
        // Handle action
        switch response.actionIdentifier {
        case acceptActionIdentifier:
            handleAcceptAction(for: response.notification)
            
        case snoozeActionIdentifier:
            handleSnoozeAction(for: response.notification)
            
        case dismissActionIdentifier:
            handleDismissAction(for: response.notification)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleDefaultAction(for: response.notification)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    
    private func handleAcceptAction(for notification: UNNotification) {
        os_log("User accepted MDI recommendation", log: log, type: .info)
        
        // TODO: Log the injection/action to Core Data
        // TODO: Open the app to log details if needed
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .mdiRecommendationAccepted,
            object: nil,
            userInfo: notification.request.content.userInfo
        )
    }
    
    private func handleSnoozeAction(for notification: UNNotification) {
        os_log("User snoozed MDI recommendation", log: log, type: .info)
        
        // Cancel current notification
        cancelNotification(with: notification.request.identifier)
        
        // TODO: Reschedule for 15 minutes later
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .mdiRecommendationSnoozed,
            object: nil,
            userInfo: notification.request.content.userInfo
        )
    }
    
    private func handleDismissAction(for notification: UNNotification) {
        os_log("User dismissed MDI recommendation", log: log, type: .info)
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .mdiRecommendationDismissed,
            object: nil,
            userInfo: notification.request.content.userInfo
        )
    }
    
    private func handleDefaultAction(for notification: UNNotification) {
        os_log("User tapped MDI notification", log: log, type: .info)
        
        // Post notification to open relevant screen in app
        NotificationCenter.default.post(
            name: .mdiRecommendationTapped,
            object: nil,
            userInfo: notification.request.content.userInfo
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mdiRecommendationAccepted = Notification.Name("mdiRecommendationAccepted")
    static let mdiRecommendationSnoozed = Notification.Name("mdiRecommendationSnoozed")
    static let mdiRecommendationDismissed = Notification.Name("mdiRecommendationDismissed")
    static let mdiRecommendationTapped = Notification.Name("mdiRecommendationTapped")
}