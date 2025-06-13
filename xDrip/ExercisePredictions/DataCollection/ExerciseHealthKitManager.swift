//
//  ExerciseHealthKitManager.swift
//  xdrip
//
//  Manages HealthKit authorization and data access for exercise predictions
//

import Foundation
import HealthKit
import os.log

/// Manages HealthKit permissions and data access for exercise-aware predictions
final class ExerciseHealthKitManager {
    
    // MARK: - Singleton
    
    static let shared = ExerciseHealthKitManager()
    
    // MARK: - Properties
    
    private let healthStore: HKHealthStore
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "ExerciseHealthKit")
    
    /// Types we want to read from HealthKit
    private var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        // Workout data
        types.insert(HKObjectType.workoutType())
        
        // Activity data
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let flights = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flights)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        
        // Heart rate (if available)
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        
        // Exercise time
        if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        
        return types
    }
    
    /// We don't write any data to HealthKit
    private let typesToWrite: Set<HKSampleType> = []
    
    // MARK: - Initialization
    
    private init() {
        guard HKHealthStore.isHealthDataAvailable() else {
            // This should never happen on real devices, only simulator
            os_log("HealthKit not available on this device", log: log, type: .error)
            self.healthStore = HKHealthStore()
            return
        }
        
        self.healthStore = HKHealthStore()
    }
    
    // MARK: - Authorization
    
    /// Check current authorization status
    func checkAuthorizationStatus() -> HKAuthorizationStatus {
        // Check status for a representative type (workouts)
        return healthStore.authorizationStatus(for: HKObjectType.workoutType())
    }
    
    /// Request HealthKit authorization with proper UI context
    /// - Parameters:
    ///   - completion: Called with success/failure after user responds
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Check if already requested to avoid pestering user
        guard !UserDefaults.standard.healthKitPermissionRequested else {
            os_log("HealthKit permission already requested", log: log, type: .info)
            let status = checkAuthorizationStatus()
            completion(status == .sharingAuthorized, nil)
            return
        }
        
        // Mark that we're requesting
        UserDefaults.standard.healthKitPermissionRequested = true
        
        os_log("Requesting HealthKit authorization", log: log, type: .info)
        
        healthStore.requestAuthorization(toShare: typesToWrite, 
                                       read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    os_log("HealthKit authorization error: %{public}@", 
                          log: self?.log ?? .default, 
                          type: .error, 
                          error.localizedDescription)
                } else {
                    os_log("HealthKit authorization completed: %{public}@", 
                          log: self?.log ?? .default, 
                          type: .info, 
                          success ? "granted" : "denied or limited")
                }
                
                // Cache the result
                UserDefaults.standard.healthKitPermissionGranted = success
                
                completion(success, error)
            }
        }
    }
    
    // MARK: - Authorization UI
    
    /// Create a privacy explanation view controller
    /// This explains why we need health data access
    func createPrivacyExplanationViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "ExercisePrivacy", bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() else {
            // Fallback to a simple alert
            return createSimplePrivacyAlert()
        }
        return viewController
    }
    
    private func createSimplePrivacyAlert() -> UIViewController {
        let alert = UIAlertController(
            title: "Exercise Data Access",
            message: """
            xDrip4iOS can use your activity and workout data to improve glucose predictions.
            
            This includes:
            • Steps and distance
            • Workouts and exercise
            • Active calories burned
            • Heart rate (if available)
            
            All data processing happens on your device. No exercise data is sent to any server.
            
            You can change this permission anytime in Settings > Privacy > Health > xDrip4iOS.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.requestAuthorization { _, _ in
                // User will see system dialog
            }
        })
        
        // Need to wrap in a view controller for presentation
        let wrapper = UIViewController()
        wrapper.view.backgroundColor = .clear
        DispatchQueue.main.async {
            wrapper.present(alert, animated: false)
        }
        return wrapper
    }
    
    // MARK: - Data Query Preparation (Not implementing queries yet)
    
    /// Check if we have authorization to read health data
    var canReadHealthData: Bool {
        // We can't definitively know read authorization status,
        // but we can check if we've requested and track the result
        return UserDefaults.standard.healthKitPermissionGranted
    }
}