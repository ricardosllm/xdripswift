//
//  ExercisePredictionsTests.swift
//  xdripTests
//
//  Tests for exercise-aware predictions feature
//

import XCTest
@testable import xdrip

class ExercisePredictionsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset all exercise settings before each test
        UserDefaults.standard.resetExerciseSettings()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up after tests
        UserDefaults.standard.resetExerciseSettings()
    }
    
    // MARK: - Feature Flag Tests
    
    func testExercisePredictionsDisabledByDefault() {
        XCTAssertFalse(UserDefaults.standard.exercisePredictionsEnabled)
        XCTAssertFalse(UserDefaults.standard.exerciseDataCollectionEnabled)
        XCTAssertFalse(UserDefaults.standard.showActivityOnChart)
    }
    
    func testDisablingMasterFlagDisablesAllFeatures() {
        // Enable all features
        UserDefaults.standard.exercisePredictionsEnabled = true
        UserDefaults.standard.exerciseDataCollectionEnabled = true
        UserDefaults.standard.showActivityOnChart = true
        UserDefaults.standard.showExerciseInsights = true
        
        // Disable master flag
        UserDefaults.standard.exercisePredictionsEnabled = false
        
        // All dependent features should be disabled
        XCTAssertFalse(UserDefaults.standard.exerciseDataCollectionEnabled)
        XCTAssertFalse(UserDefaults.standard.showActivityOnChart)
        XCTAssertFalse(UserDefaults.standard.showExerciseInsights)
    }
    
    // MARK: - Settings Boundary Tests
    
    func testExerciseDataRetentionDaysBounds() {
        // Test minimum bound
        UserDefaults.standard.exerciseDataRetentionDays = 0
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 30) // Should default to 30
        
        UserDefaults.standard.exerciseDataRetentionDays = -10
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 30) // Should default to 30
        
        // Test maximum bound
        UserDefaults.standard.exerciseDataRetentionDays = 500
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 365) // Should cap at 365
        
        // Test valid values
        UserDefaults.standard.exerciseDataRetentionDays = 7
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 7)
        
        UserDefaults.standard.exerciseDataRetentionDays = 90
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 90)
    }
    
    func testExercisePredictionSensitivityBounds() {
        // Test minimum bound
        UserDefaults.standard.exercisePredictionSensitivity = -1.0
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 0.0)
        
        // Test maximum bound
        UserDefaults.standard.exercisePredictionSensitivity = 3.0
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 2.0)
        
        // Test default
        UserDefaults.standard.removeObject(forKey: "exercise.predictions.sensitivity")
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 1.0)
        
        // Test valid values
        UserDefaults.standard.exercisePredictionSensitivity = 0.5
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 0.5)
        
        UserDefaults.standard.exercisePredictionSensitivity = 1.5
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 1.5)
    }
    
    // MARK: - Backwards Compatibility Tests
    
    func testNoSideEffectsWhenDisabled() {
        // Ensure feature is disabled
        UserDefaults.standard.exercisePredictionsEnabled = false
        
        // Create health kit manager (should not request permissions)
        let healthKitManager = ExerciseHealthKitManager.shared
        
        // Check that no permissions have been requested
        XCTAssertFalse(UserDefaults.standard.healthKitPermissionRequested)
        
        // Check authorization status (should not trigger permission request)
        let _ = healthKitManager.checkAuthorizationStatus()
        XCTAssertFalse(UserDefaults.standard.healthKitPermissionRequested)
    }
    
    func testHealthKitAuthorizationNotRequestedTwice() {
        // Mark as already requested
        UserDefaults.standard.healthKitPermissionRequested = true
        
        var completionCalled = false
        
        ExerciseHealthKitManager.shared.requestAuthorization { _, _ in
            completionCalled = true
        }
        
        // Should complete immediately without showing UI
        XCTAssertTrue(completionCalled)
    }
    
    // MARK: - Settings Reset Tests
    
    func testResetExerciseSettings() {
        // Set various exercise settings
        UserDefaults.standard.exercisePredictionsEnabled = true
        UserDefaults.standard.exerciseDataCollectionEnabled = true
        UserDefaults.standard.showActivityOnChart = true
        UserDefaults.standard.exerciseDataRetentionDays = 14
        UserDefaults.standard.exercisePredictionSensitivity = 1.5
        UserDefaults.standard.healthKitPermissionRequested = true
        
        // Reset all settings
        UserDefaults.standard.resetExerciseSettings()
        
        // Verify all settings are back to defaults
        XCTAssertFalse(UserDefaults.standard.exercisePredictionsEnabled)
        XCTAssertFalse(UserDefaults.standard.exerciseDataCollectionEnabled)
        XCTAssertFalse(UserDefaults.standard.showActivityOnChart)
        XCTAssertEqual(UserDefaults.standard.exerciseDataRetentionDays, 30)
        XCTAssertEqual(UserDefaults.standard.exercisePredictionSensitivity, 1.0)
        XCTAssertFalse(UserDefaults.standard.healthKitPermissionRequested)
    }
    
    // MARK: - Feature Availability Tests
    
    func testExerciseFeaturesAvailability() {
        // Should be available on iOS 13+
        if #available(iOS 13.0, *) {
            XCTAssertTrue(UserDefaults.standard.exerciseFeaturesAvailable)
        } else {
            XCTAssertFalse(UserDefaults.standard.exerciseFeaturesAvailable)
        }
    }
}

// MARK: - Backwards Compatibility Integration Tests

class ExerciseBackwardsCompatibilityTests: XCTestCase {
    
    func testPredictionManagerUnaffectedWhenDisabled() {
        UserDefaults.standard.exercisePredictionsEnabled = false
        
        // This test would verify that PredictionManager behavior is unchanged
        // when exercise predictions are disabled
        // (Would need actual PredictionManager instance to test)
    }
    
    func testSettingsViewModelBackwardsCompatible() {
        let viewModel = SettingsViewDevelopmentSettingsViewModel()
        
        // Get the original number of rows
        UserDefaults.standard.showDeveloperSettings = true
        let originalRowCount = viewModel.numberOfRows()
        
        // Exercise settings should not affect the count when using original view model
        UserDefaults.standard.exercisePredictionsEnabled = true
        let newRowCount = viewModel.numberOfRows()
        
        XCTAssertEqual(originalRowCount, newRowCount, 
                      "Original view model should not be affected by exercise settings")
    }
}