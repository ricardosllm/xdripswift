import XCTest
@testable import xdrip

class MDIRecommendationEngineTests: XCTestCase {
    
    var engine: MDIRecommendationEngine!
    var coreDataManager: CoreDataManager!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        coreDataManager = CoreDataManager(modelName: "xDripModel", inMemory: true)
        engine = MDIRecommendationEngine(coreDataManager: coreDataManager)
        
        // Set up default user settings
        UserDefaults.standard.mdiMaxCorrectionBolus = 5.0
        UserDefaults.standard.mdiMaxMealBolus = 10.0
        UserDefaults.standard.mdiMinTimeBetweenCorrections = 120 // 2 hours
        UserDefaults.standard.mdiMinBGForCorrection = 120
        UserDefaults.standard.mdiMaxBGForNoAction = 180
        UserDefaults.standard.mdiMaxIOBMultiplier = 2.0
        UserDefaults.standard.targetMarkValueInUserChosenUnit = 100
        UserDefaults.standard.bloodGlucoseUnitIsMgDl = true
        
        // Set up profile data
        UserDefaults.standard.insulinSensitivityFactorInUserChosenUnit = 50
        UserDefaults.standard.carbRatioInGrams = 10
        UserDefaults.standard.insulinType = 2 // Rapid acting
    }
    
    override func tearDown() {
        engine = nil
        coreDataManager = nil
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testNoRecommendationForNormalBG() {
        // Given: Normal BG in range
        let bgReading = createBgReading(value: 110, minutesAgo: 2)
        let treatments: [TreatmentEntry] = []
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: treatments,
            pendingCarbs: nil
        )
        
        // Then: Should return no action recommendation
        XCTAssertNotNil(recommendation)
        if case .none(let reason) = recommendation?.type {
            XCTAssertTrue(reason.contains("in range"))
        } else {
            XCTFail("Expected no action recommendation")
        }
    }
    
    func testCorrectionRecommendationForHighBG() {
        // Given: High BG above correction threshold
        let bgReading = createBgReading(value: 250, minutesAgo: 2)
        let treatments: [TreatmentEntry] = []
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: treatments,
            pendingCarbs: nil
        )
        
        // Then: Should recommend correction
        XCTAssertNotNil(recommendation)
        if case .correction(let units, let reason) = recommendation?.type {
            XCTAssertGreaterThan(units, 0)
            XCTAssertTrue(reason.contains("correction"))
            XCTAssertEqual(recommendation?.urgency, .normal)
        } else {
            XCTFail("Expected correction recommendation")
        }
    }
    
    func testUrgentRecommendationForVeryHighBG() {
        // Given: Very high BG
        let bgReading = createBgReading(value: 350, minutesAgo: 2)
        let treatments: [TreatmentEntry] = []
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: treatments,
            pendingCarbs: nil
        )
        
        // Then: Should be urgent
        XCTAssertNotNil(recommendation)
        XCTAssertEqual(recommendation?.urgency, .urgent)
    }
    
    func testSafetyCheckPreventsOverCorrection() {
        // Given: High BG but recent insulin
        let bgReading = createBgReading(value: 250, minutesAgo: 2)
        let recentInsulin = createTreatment(type: .Insulin, value: 3.0, minutesAgo: 30)
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: [recentInsulin],
            pendingCarbs: nil
        )
        
        // Then: Should fail safety check for recent correction
        XCTAssertNotNil(recommendation)
        let recentCorrectionCheck = recommendation?.safetyChecks.first { $0.name == "Recent Correction Check" }
        XCTAssertNotNil(recentCorrectionCheck)
        XCTAssertFalse(recentCorrectionCheck?.passed ?? true)
    }
    
    func testMealBolusRecommendation() {
        // Given: Normal BG with pending carbs
        let bgReading = createBgReading(value: 110, minutesAgo: 2)
        let treatments: [TreatmentEntry] = []
        let pendingCarbs = 50.0
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: treatments,
            pendingCarbs: pendingCarbs
        )
        
        // Then: Should recommend meal bolus
        XCTAssertNotNil(recommendation)
        if case .meal(let units, let carbs, _) = recommendation?.type {
            XCTAssertEqual(units, 5.0) // 50g / 10g per unit
            XCTAssertEqual(carbs, pendingCarbs)
        } else {
            XCTFail("Expected meal bolus recommendation")
        }
    }
    
    func testCombinedBolusRecommendation() {
        // Given: High BG with pending carbs
        let bgReading = createBgReading(value: 200, minutesAgo: 2)
        let treatments: [TreatmentEntry] = []
        let pendingCarbs = 30.0
        
        // When: Generate recommendation
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: treatments,
            pendingCarbs: pendingCarbs
        )
        
        // Then: Should recommend combined bolus
        XCTAssertNotNil(recommendation)
        if case .both(let correctionUnits, let mealUnits, let carbs, _) = recommendation?.type {
            XCTAssertGreaterThan(correctionUnits, 0)
            XCTAssertEqual(mealUnits, 3.0) // 30g / 10g per unit
            XCTAssertEqual(carbs, pendingCarbs)
        } else {
            XCTFail("Expected combined bolus recommendation")
        }
    }
    
    func testRecommendationExpiry() {
        // Given: Normal recommendation
        let bgReading = createBgReading(value: 250, minutesAgo: 2)
        let recommendation = engine.generateRecommendation(
            bgReadings: [bgReading],
            treatments: [],
            pendingCarbs: nil
        )
        
        // Then: Should have 15 minute expiry
        XCTAssertNotNil(recommendation)
        let expectedExpiry = Date().addingTimeInterval(15 * 60)
        let actualExpiry = recommendation?.expires ?? Date()
        XCTAssertEqual(actualExpiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createBgReading(value: Double, minutesAgo: Int) -> BgReading {
        let bgReading = BgReading(context: coreDataManager.mainManagedObjectContext)
        bgReading.calculatedValue = value
        bgReading.timeStamp = Date().addingTimeInterval(-Double(minutesAgo * 60))
        bgReading.calculatedValueSlope = 0
        return bgReading
    }
    
    private func createTreatment(type: TreatmentType, value: Double, minutesAgo: Int) -> TreatmentEntry {
        let treatment = TreatmentEntry(context: coreDataManager.mainManagedObjectContext)
        treatment.treatmentType = type
        treatment.value = value
        treatment.date = Date().addingTimeInterval(-Double(minutesAgo * 60))
        treatment.id = UUID().uuidString
        return treatment
    }
}