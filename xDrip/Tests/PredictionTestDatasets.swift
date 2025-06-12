import Foundation

/// Comprehensive test datasets for glucose prediction algorithm testing
/// Based on physiological models and real-world diabetes scenarios
struct PredictionTestDatasets {
    
    // MARK: - Test Data Models
    
    struct TestReading {
        let timestamp: Date
        let glucoseValue: Double // mg/dL
        let trend: String?
    }
    
    struct TestTreatment {
        let timestamp: Date
        let type: TreatmentType
        let value: Double
        
        enum TreatmentType {
            case insulin
            case carbs
            case exercise
        }
    }
    
    struct TestScenario {
        let name: String
        let description: String
        let readings: [TestReading]
        let treatments: [TestTreatment]
        let expectedOutcomes: String
    }
    
    // MARK: - Base Time Reference
    
    static let baseTime = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
    
    // MARK: - Test Scenarios
    
    // Scenario 1: Stable Overnight (No Treatments)
    static let stableOvernightScenario = TestScenario(
        name: "Stable Overnight",
        description: "Stable glucose levels overnight with no treatments",
        readings: (0..<48).map { i in
            TestReading(
                timestamp: baseTime.addingTimeInterval(Double(i * 5 * 60)), // 5-minute intervals
                glucoseValue: 110 + sin(Double(i) * 0.1) * 5, // Slight natural variation
                trend: "Flat"
            )
        },
        treatments: [],
        expectedOutcomes: "Predictions should show continued stability with minimal variation"
    )
    
    // Scenario 2: Breakfast with Insulin
    static let breakfastScenario = TestScenario(
        name: "Breakfast with Insulin",
        description: "Typical breakfast scenario with pre-bolus insulin",
        readings: generateBreakfastReadings(),
        treatments: [
            TestTreatment(timestamp: baseTime.addingTimeInterval(30 * 60), type: .insulin, value: 6.0), // 6 units
            TestTreatment(timestamp: baseTime.addingTimeInterval(45 * 60), type: .carbs, value: 45.0) // 45g carbs
        ],
        expectedOutcomes: "Predictions should show initial dip from insulin, then rise from carbs, peaking around 90-120 minutes"
    )
    
    // Scenario 3: Exercise Impact
    static let exerciseScenario = TestScenario(
        name: "Exercise Impact",
        description: "Moderate exercise causing glucose drop",
        readings: generateExerciseReadings(),
        treatments: [
            TestTreatment(timestamp: baseTime.addingTimeInterval(60 * 60), type: .exercise, value: 30.0) // 30 min exercise
        ],
        expectedOutcomes: "Predictions should anticipate glucose drop during and after exercise"
    )
    
    // Scenario 4: Dawn Phenomenon
    static let dawnPhenomenonScenario = TestScenario(
        name: "Dawn Phenomenon",
        description: "Early morning glucose rise without treatment",
        readings: generateDawnPhenomenonReadings(),
        treatments: [],
        expectedOutcomes: "Predictions should capture the upward trend starting around 4-5 AM"
    )
    
    // Scenario 5: Large Meal with Delayed Bolus
    static let largeMealScenario = TestScenario(
        name: "Large Meal Delayed Bolus",
        description: "Pizza meal with delayed insulin dosing",
        readings: generateLargeMealReadings(),
        treatments: [
            TestTreatment(timestamp: baseTime, type: .carbs, value: 80.0), // 80g carbs
            TestTreatment(timestamp: baseTime.addingTimeInterval(15 * 60), type: .insulin, value: 8.0), // Delayed bolus
            TestTreatment(timestamp: baseTime.addingTimeInterval(120 * 60), type: .insulin, value: 2.0) // Extended bolus
        ],
        expectedOutcomes: "Predictions should show rapid rise, partial control, and extended absorption pattern"
    )
    
    // Scenario 6: Hypoglycemia Treatment
    static let hypoTreatmentScenario = TestScenario(
        name: "Hypoglycemia Treatment",
        description: "Low glucose treated with fast-acting carbs",
        readings: generateHypoReadings(),
        treatments: [
            TestTreatment(timestamp: baseTime.addingTimeInterval(30 * 60), type: .carbs, value: 15.0) // 15g fast carbs
        ],
        expectedOutcomes: "Predictions should show rapid glucose rise within 15-20 minutes"
    )
    
    // Scenario 7: Sick Day Pattern
    static let sickDayScenario = TestScenario(
        name: "Sick Day Pattern",
        description: "Elevated glucose with insulin resistance",
        readings: generateSickDayReadings(),
        treatments: [
            TestTreatment(timestamp: baseTime, type: .insulin, value: 10.0), // Higher insulin needs
            TestTreatment(timestamp: baseTime.addingTimeInterval(240 * 60), type: .insulin, value: 8.0)
        ],
        expectedOutcomes: "Predictions should show slower response to insulin and persistent elevation"
    )
    
    // Scenario 8: Complex Day Pattern
    static let complexDayScenario = TestScenario(
        name: "Complex Day Pattern",
        description: "Multiple meals, corrections, and activities",
        readings: generateComplexDayReadings(),
        treatments: [
            // Breakfast
            TestTreatment(timestamp: baseTime.addingTimeInterval(420 * 60), type: .insulin, value: 5.0),
            TestTreatment(timestamp: baseTime.addingTimeInterval(435 * 60), type: .carbs, value: 40.0),
            // Mid-morning correction
            TestTreatment(timestamp: baseTime.addingTimeInterval(600 * 60), type: .insulin, value: 2.0),
            // Lunch
            TestTreatment(timestamp: baseTime.addingTimeInterval(720 * 60), type: .insulin, value: 6.0),
            TestTreatment(timestamp: baseTime.addingTimeInterval(735 * 60), type: .carbs, value: 50.0),
            // Afternoon exercise
            TestTreatment(timestamp: baseTime.addingTimeInterval(900 * 60), type: .exercise, value: 45.0),
            // Dinner
            TestTreatment(timestamp: baseTime.addingTimeInterval(1080 * 60), type: .insulin, value: 7.0),
            TestTreatment(timestamp: baseTime.addingTimeInterval(1095 * 60), type: .carbs, value: 60.0)
        ],
        expectedOutcomes: "Predictions should handle multiple overlapping insulin and carb effects accurately"
    )
    
    // MARK: - Helper Functions
    
    private static func generateBreakfastReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 240 // 4 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 100.0
            
            if hours < 0.5 {
                // Pre-meal steady
                glucose = 100.0
            } else if hours < 1.0 {
                // Insulin effect starting
                glucose = 100.0 - (hours - 0.5) * 20.0
            } else if hours < 2.5 {
                // Carb absorption dominant
                glucose = 90.0 + (hours - 1.0) * 60.0 - pow(hours - 1.0, 2) * 15.0
            } else {
                // Return to baseline
                glucose = 120.0 - (hours - 2.5) * 20.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -3...3),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateExerciseReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 180 // 3 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 140.0
            
            if hours < 1.0 {
                // Pre-exercise
                glucose = 140.0
            } else if hours < 1.5 {
                // During exercise
                glucose = 140.0 - (hours - 1.0) * 80.0
            } else if hours < 2.5 {
                // Post-exercise continued drop
                glucose = 100.0 - (hours - 1.5) * 20.0
            } else {
                // Stabilization
                glucose = 80.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -2...2),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateDawnPhenomenonReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 480 // 8 hours (midnight to 8 AM)
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 100.0
            
            if hours < 4.0 {
                // Stable overnight
                glucose = 100.0 + sin(hours * 0.5) * 5.0
            } else if hours < 7.0 {
                // Dawn phenomenon rise
                glucose = 100.0 + (hours - 4.0) * 15.0
            } else {
                // Plateau
                glucose = 145.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -3...3),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateLargeMealReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 360 // 6 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 120.0
            
            if hours < 0.5 {
                // Rapid initial rise
                glucose = 120.0 + hours * 200.0
            } else if hours < 2.0 {
                // Partial control from delayed bolus
                glucose = 220.0 - (hours - 0.5) * 30.0
            } else if hours < 4.0 {
                // Extended absorption
                glucose = 175.0 + sin((hours - 2.0) * 2.0) * 25.0
            } else {
                // Gradual return
                glucose = 175.0 - (hours - 4.0) * 25.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -4...4),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateHypoReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 120 // 2 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 80.0
            
            if hours < 0.5 {
                // Dropping
                glucose = 80.0 - hours * 40.0
            } else if hours < 0.75 {
                // Treatment starting to work
                glucose = 60.0 + (hours - 0.5) * 80.0
            } else if hours < 1.5 {
                // Recovery
                glucose = 80.0 + (hours - 0.75) * 40.0
            } else {
                // Stabilization
                glucose = 110.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -2...2),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateSickDayReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 480 // 8 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 250.0
            
            // Slow, resistant response to insulin
            glucose = 250.0 - hours * 10.0 + sin(hours * 0.5) * 15.0
            
            // Keep elevated
            glucose = max(glucose, 180.0)
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -5...5),
                trend: nil
            ))
        }
        
        return readings
    }
    
    private static func generateComplexDayReadings() -> [TestReading] {
        var readings: [TestReading] = []
        let totalMinutes = 1440 // 24 hours
        
        for minute in stride(from: 0, to: totalMinutes, by: 5) {
            let hours = Double(minute) / 60.0
            var glucose = 110.0
            
            // Overnight
            if hours < 7.0 {
                glucose = 110.0 + sin(hours * 0.3) * 10.0
            }
            // Breakfast effect
            else if hours < 10.0 {
                let mealHours = hours - 7.0
                glucose = 110.0 + mealHours * 40.0 - pow(mealHours, 2) * 10.0
            }
            // Mid-morning
            else if hours < 12.0 {
                glucose = 150.0 - (hours - 10.0) * 15.0
            }
            // Lunch effect
            else if hours < 15.0 {
                let mealHours = hours - 12.0
                glucose = 120.0 + mealHours * 35.0 - pow(mealHours, 2) * 8.0
            }
            // Exercise drop
            else if hours < 16.5 {
                glucose = 140.0 - (hours - 15.0) * 40.0
            }
            // Dinner effect
            else if hours < 20.0 {
                let mealHours = hours - 18.0
                glucose = 100.0 + mealHours * 45.0 - pow(mealHours, 2) * 12.0
            }
            // Evening
            else {
                glucose = 130.0 - (hours - 20.0) * 5.0
            }
            
            readings.append(TestReading(
                timestamp: baseTime.addingTimeInterval(Double(minute * 60)),
                glucoseValue: glucose + Double.random(in: -4...4),
                trend: nil
            ))
        }
        
        return readings
    }
    
    // MARK: - All Scenarios
    
    static let allScenarios = [
        stableOvernightScenario,
        breakfastScenario,
        exerciseScenario,
        dawnPhenomenonScenario,
        largeMealScenario,
        hypoTreatmentScenario,
        sickDayScenario,
        complexDayScenario
    ]
}