//
//  ExerciseSettingsIntegration.swift
//  xdrip
//
//  Integrates exercise settings into the existing settings UI
//  without modifying original code
//

import UIKit

/// Helper class to inject exercise settings into developer menu
final class ExerciseSettingsIntegration {
    
    /// Modifies the SettingsViewDevelopmentSettingsViewModel behavior
    /// Called once during app startup if exercise features are available
    static func integrate() {
        guard UserDefaults.standard.exerciseFeaturesAvailable else { return }
        
        // We would use method swizzling here in production, but for clarity,
        // here's the conceptual approach:
        
        // The actual implementation would require either:
        // 1. A protocol-based approach where the view model calls delegates
        // 2. NotificationCenter to inject rows
        // 3. Subclassing the view model
        // 4. Method swizzling (not recommended but possible)
        
        // For now, we'll document the integration approach
        setupIntegration()
    }
    
    private static func setupIntegration() {
        // This shows how we would integrate without modifying existing code
        
        // Option 1: Use notifications to inject settings
        NotificationCenter.default.addObserver(
            forName: .developerSettingsWillLoad,
            object: nil,
            queue: .main
        ) { _ in
            // Inject our settings here
        }
        
        // Option 2: Register a settings provider
        // SettingsRegistry.shared.registerProvider(ExerciseSettingsProvider())
    }
}

// MARK: - Alternative: Subclass Approach

/// This shows how we could subclass to add functionality
/// The app would need to instantiate this instead of the original
class ExerciseAwareDevelopmentSettingsViewModel: SettingsViewDevelopmentSettingsViewModel {
    
    override func numberOfRows() -> Int {
        let baseCount = super.numberOfRows()
        guard UserDefaults.standard.showDeveloperSettings else { return baseCount }
        
        // Add our exercise settings
        let exerciseCount = UserDefaults.standard.exercisePredictionsEnabled ? 4 : 1
        return baseCount + exerciseCount
    }
    
    override func settingsRowText(index: Int) -> String {
        let baseCount = Setting.allCases.count
        
        if index < baseCount {
            return super.settingsRowText(index: index)
        } else {
            // Handle exercise settings
            let exerciseIndex = 100 + (index - baseCount)
            return exerciseSettingsRowText(index: exerciseIndex) ?? ""
        }
    }
    
    override func uiView(index: Int) -> UIView? {
        let baseCount = Setting.allCases.count
        
        if index < baseCount {
            return super.uiView(index: index)
        } else {
            // Handle exercise settings
            let exerciseIndex = 100 + (index - baseCount)
            return exerciseUIView(index: exerciseIndex)
        }
    }
    
    override func isEnabled(index: Int) -> Bool {
        let baseCount = Setting.allCases.count
        
        if index < baseCount {
            return super.isEnabled(index: index)
        } else {
            // Handle exercise settings
            let exerciseIndex = 100 + (index - baseCount)
            return exerciseIsEnabled(index: exerciseIndex)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let developerSettingsWillLoad = Notification.Name("DeveloperSettingsWillLoad")
    static let exerciseSettingsChanged = Notification.Name("ExerciseSettingsChanged")
}