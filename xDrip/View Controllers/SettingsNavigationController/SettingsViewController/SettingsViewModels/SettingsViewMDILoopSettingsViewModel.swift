import UIKit
import os

// Notification names removed - using simple info text instead to prevent crashes

/// Settings view model for MDI Loop Emulation settings
class SettingsViewMDILoopSettingsViewModel: SettingsViewModelProtocol {
    
    // MARK: - Private Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: "SettingsViewMDILoopSettingsViewModel")
    
    /// for reloading rows
    private var rowReloadClosure: ((Int) -> Void)?
    
    /// reference to the viewcontroller
    private weak var uIViewController: UIViewController?
    
    // MARK: - Settings Options
    
    private enum Setting: Int, CaseIterable {
        /// enable/disable MDI loop
        case enableMDILoop = 0
        
        /// enable/disable notifications
        case enableNotifications = 1
        
        /// notification urgency threshold
        case notificationUrgencyThreshold = 2
        
        /// show prediction impact
        case showPredictionImpact = 3
        
        /// enable pre-meal reminders
        case preMealReminders = 4
        
        /// notification sound
        case notificationSound = 5
        
        /// include graph in notification
        case includeGraphInNotification = 6
        
        /// basal insulin units per day
        case basalUnitsPerDay = 7
        
        /// view recommendation history
        case viewHistory = 8
        
        /// help and documentation
        case help = 9
    }
    
    // MARK: - Protocol Implementation
    
    func storeRowReloadClosure(rowReloadClosure: @escaping (Int) -> Void) {
        self.rowReloadClosure = rowReloadClosure
    }
    
    func storeUIViewController(uIViewController: UIViewController) {
        self.uIViewController = uIViewController
    }
    
    func storeMessageHandler(messageHandler: @escaping (String, String) -> Void) {
        // Not needed for this view model
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        // Only the enable/disable needs to refresh the complete view to show/hide other settings
        if let setting = Setting(rawValue: index) {
            return setting == .enableMDILoop
        }
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // All rows are enabled if MDI Loop is enabled, except the main toggle itself
        if let setting = Setting(rawValue: index) {
            if setting == .enableMDILoop {
                return true
            }
            return UserDefaults.standard.mdiLoopEnabled
        }
        return false
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        if let setting = Setting(rawValue: index) {
            switch setting {
            case .notificationUrgencyThreshold:
                let currentValue = UserDefaults.standard.mdiNotificationUrgencyThreshold
                let selectedIndex = ["urgent", "high", "any"].firstIndex(of: currentValue) ?? 1
                
                return SettingsSelectedRowAction.selectFromList(
                    title: "Notification Threshold",
                    data: ["Urgent Only", "High and Urgent", "Any Prediction"],
                    selectedRow: selectedIndex,
                    actionTitle: nil,
                    cancelTitle: nil,
                    actionHandler: { index in
                        let values = ["urgent", "high", "any"]
                        UserDefaults.standard.mdiNotificationUrgencyThreshold = values[index]
                    },
                    cancelHandler: nil,
                    didSelectRowHandler: nil
                )
                
            case .basalUnitsPerDay:
                return SettingsSelectedRowAction.askText(
                    title: "Basal Insulin",
                    message: "Enter your total daily basal insulin dose (e.g., Lantus, Tresiba, Toujeo)",
                    keyboardType: .decimalPad,
                    text: String(format: "%.1f", UserDefaults.standard.mdiBasalUnitsPerDay),
                    placeHolder: "24.0",
                    actionTitle: nil,
                    cancelTitle: nil,
                    actionHandler: { text in
                        if let units = Double(text), units >= 0 {
                            UserDefaults.standard.mdiBasalUnitsPerDay = units
                        }
                    },
                    cancelHandler: nil,
                    inputValidator: { text in
                        guard let units = Double(text), units >= 0, units <= 200 else {
                            return "Please enter a valid number between 0 and 200"
                        }
                        return nil
                    }
                )
                
            case .viewHistory:
                // Temporarily disable this feature to prevent crashes
                return .showInfoText(
                    title: "Coming Soon", 
                    message: "The recommendation history feature is currently being improved and will be available in a future update."
                )
                
            case .help:
                // Show simple help text instead of navigating to prevent crashes
                return .showInfoText(
                    title: "MDI Loop Help",
                    message: "MDI Loop provides insulin dosing recommendations for Multiple Daily Injection users.\n\nWhen enabled, it analyzes your glucose trends and suggests corrections based on your settings.\n\nNotifications will appear when action may be needed. You can accept, snooze, or dismiss each recommendation.\n\nAlways verify recommendations with your clinical judgment."
                )
                
            default:
                return .nothing
            }
        }
        return .nothing
    }
    
    func sectionTitle() -> String? {
        return "💉 MDI Loop"
    }
    
    func numberOfRows() -> Int {
        // Show only the enable toggle if disabled, all settings if enabled
        return UserDefaults.standard.mdiLoopEnabled ? Setting.allCases.count : 1
    }
    
    func settingsRowText(index: Int) -> String {
        if let setting = Setting(rawValue: index) {
            switch setting {
            case .enableMDILoop:
                return "Enable MDI Loop"
            case .enableNotifications:
                return "Enable Notifications"
            case .notificationUrgencyThreshold:
                return "Notification Threshold"
            case .showPredictionImpact:
                return "Show Prediction Impact"
            case .preMealReminders:
                return "Pre-Meal Reminders"
            case .notificationSound:
                return "Notification Sound"
            case .includeGraphInNotification:
                return "Include Graph"
            case .basalUnitsPerDay:
                return "Basal Insulin (units/day)"
            case .viewHistory:
                return "View History"
            case .help:
                return "Help"
            }
        }
        return ""
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        if let setting = Setting(rawValue: index) {
            switch setting {
            case .notificationUrgencyThreshold, .basalUnitsPerDay, .viewHistory, .help:
                return .disclosureIndicator
            default:
                return .none
            }
        }
        return .none
    }
    
    func detailedText(index: Int) -> String? {
        if let setting = Setting(rawValue: index) {
            switch setting {
            case .notificationUrgencyThreshold:
                let value = UserDefaults.standard.mdiNotificationUrgencyThreshold
                switch value {
                case "urgent":
                    return "Urgent Only"
                case "high":
                    return "High and Urgent"
                case "any":
                    return "Any Prediction"
                default:
                    return "High and Urgent"
                }
            case .basalUnitsPerDay:
                let units = UserDefaults.standard.mdiBasalUnitsPerDay
                return String(format: "%.1f units", units)
            default:
                return nil
            }
        }
        return nil
    }
    
    func uiView(index: Int) -> UIView? {
        if let setting = Setting(rawValue: index) {
            switch setting {
            case .enableMDILoop:
                return UISwitch(isOn: UserDefaults.standard.mdiLoopEnabled, action: { isOn in
                    UserDefaults.standard.mdiLoopEnabled = isOn
                    
                    // The loop will be started/stopped by RootViewController
                    // which has access to CoreDataManager
                })
                
            case .enableNotifications:
                return UISwitch(isOn: UserDefaults.standard.mdiNotificationsEnabled, action: { isOn in
                    UserDefaults.standard.mdiNotificationsEnabled = isOn
                })
                
            case .showPredictionImpact:
                return UISwitch(isOn: UserDefaults.standard.mdiShowPredictionImpact, action: { isOn in
                    UserDefaults.standard.mdiShowPredictionImpact = isOn
                })
                
            case .preMealReminders:
                return UISwitch(isOn: UserDefaults.standard.mdiPreMealRemindersEnabled, action: { isOn in
                    UserDefaults.standard.mdiPreMealRemindersEnabled = isOn
                })
                
            case .notificationSound:
                return UISwitch(isOn: UserDefaults.standard.mdiNotificationSoundEnabled, action: { isOn in
                    UserDefaults.standard.mdiNotificationSoundEnabled = isOn
                })
                
            case .includeGraphInNotification:
                return UISwitch(isOn: UserDefaults.standard.mdiIncludeGraphInNotification, action: { isOn in
                    UserDefaults.standard.mdiIncludeGraphInNotification = isOn
                })
                
            default:
                return nil
            }
        }
        return nil
    }
    
}