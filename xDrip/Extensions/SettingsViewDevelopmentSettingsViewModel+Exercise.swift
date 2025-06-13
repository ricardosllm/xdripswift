//
//  SettingsViewDevelopmentSettingsViewModel+Exercise.swift
//  xdrip
//
//  Extension to add exercise prediction settings to developer menu
//

import UIKit

// MARK: - Exercise Settings

extension SettingsViewDevelopmentSettingsViewModel {
    
    /// Additional setting cases for exercise predictions
    /// We use high numbers to avoid conflicts with existing settings
    fileprivate enum ExerciseSetting: Int {
        case exercisePredictionsEnabled = 100
        case exerciseDataCollection = 101
        case showActivityOnChart = 102
        case exerciseDebugLogging = 103
    }
    
    /// Check if this is an exercise-related setting
    private func isExerciseSetting(index: Int) -> Bool {
        return index >= 100
    }
    
    /// Get the exercise setting for an index
    private func exerciseSetting(for index: Int) -> ExerciseSetting? {
        return ExerciseSetting(rawValue: index)
    }
    
    // MARK: - Override Methods to Add Exercise Settings
    
    /// We'll use method swizzling or subclassing to inject these
    /// For now, these are the implementations that would be used
    
    func exerciseSettingsRowText(index: Int) -> String? {
        guard let setting = exerciseSetting(for: index) else { return nil }
        
        switch setting {
        case .exercisePredictionsEnabled:
            return "Exercise-Aware Predictions"
        case .exerciseDataCollection:
            return "Collect Exercise Data"
        case .showActivityOnChart:
            return "Show Activity on Chart"
        case .exerciseDebugLogging:
            return "Exercise Debug Logging"
        }
    }
    
    func exerciseAccessoryType(index: Int) -> UITableViewCell.AccessoryType? {
        guard exerciseSetting(for: index) != nil else { return nil }
        return .none // All exercise settings use switches
    }
    
    func exerciseDetailedText(index: Int) -> String? {
        guard let setting = exerciseSetting(for: index) else { return nil }
        
        switch setting {
        case .exercisePredictionsEnabled:
            return UserDefaults.standard.exercisePredictionsEnabled ? "Beta" : nil
        case .exerciseDataCollection:
            return UserDefaults.standard.healthKitPermissionGranted ? "Active" : "Inactive"
        case .showActivityOnChart:
            return nil
        case .exerciseDebugLogging:
            return nil
        }
    }
    
    func exerciseUIView(index: Int) -> UIView? {
        guard let setting = exerciseSetting(for: index) else { return nil }
        
        switch setting {
        case .exercisePredictionsEnabled:
            return UISwitch(isOn: UserDefaults.standard.exercisePredictionsEnabled, action: {
                (isOn: Bool) in
                UserDefaults.standard.exercisePredictionsEnabled = isOn
                
                // If enabling for first time, show privacy explanation
                if isOn && !UserDefaults.standard.healthKitPermissionRequested {
                    DispatchQueue.main.async {
                        self.showExercisePrivacyExplanation()
                    }
                }
                
                // Reload to show/hide sub-options
                self.sectionReloadClosure?()
            })
            
        case .exerciseDataCollection:
            return UISwitch(isOn: UserDefaults.standard.exerciseDataCollectionEnabled, action: {
                (isOn: Bool) in
                if isOn {
                    // Request HealthKit permission if needed
                    ExerciseHealthKitManager.shared.requestAuthorization { success, _ in
                        DispatchQueue.main.async {
                            UserDefaults.standard.exerciseDataCollectionEnabled = success
                            self.sectionReloadClosure?()
                        }
                    }
                } else {
                    UserDefaults.standard.exerciseDataCollectionEnabled = false
                }
            })
            
        case .showActivityOnChart:
            return UISwitch(isOn: UserDefaults.standard.showActivityOnChart, action: {
                (isOn: Bool) in
                UserDefaults.standard.showActivityOnChart = isOn
            })
            
        case .exerciseDebugLogging:
            return UISwitch(isOn: UserDefaults.standard.exerciseDebugLogging, action: {
                (isOn: Bool) in
                UserDefaults.standard.exerciseDebugLogging = isOn
            })
        }
    }
    
    func exerciseIsEnabled(index: Int) -> Bool {
        guard let setting = exerciseSetting(for: index) else { return true }
        
        switch setting {
        case .exercisePredictionsEnabled:
            return true // Always enabled
        case .exerciseDataCollection, .showActivityOnChart, .exerciseDebugLogging:
            // Only enabled if main feature is on
            return UserDefaults.standard.exercisePredictionsEnabled
        }
    }
    
    // MARK: - Helper Methods
    
    private func showExercisePrivacyExplanation() {
        guard let viewController = self.uIViewController else { return }
        
        let alert = UIAlertController(
            title: "Exercise-Aware Predictions",
            message: """
            This feature uses your activity and workout data to improve glucose predictions.
            
            • All data processing happens on your device
            • No exercise data is sent to any server
            • You control which data is used
            
            You'll be asked to grant access to health data on the next screen.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            UserDefaults.standard.exercisePredictionsEnabled = false
            self.sectionReloadClosure?()
        })
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            // Will proceed with HealthKit authorization when they enable data collection
        })
        
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Integration Helper
    
    /// Returns the number of exercise settings to add
    var exerciseSettingsCount: Int {
        guard UserDefaults.standard.showDeveloperSettings else { return 0 }
        
        if UserDefaults.standard.exercisePredictionsEnabled {
            return 4 // Show all options
        } else {
            return 1 // Just show the main toggle
        }
    }
}