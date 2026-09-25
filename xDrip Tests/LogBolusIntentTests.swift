//
//  LogBolusIntentTests.swift
//  xdripTests
//
//  Created by Ricardo Mota on 25/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class LogBolusIntentTests: XCTestCase {
    /// Siri can only offer listed amounts, so the list is the half-unit grid and the safety ceiling.
    func testAmountsCoverHalfUnitStepsUpToTwentyUnits() {
        let units = BolusAmount.allCases.map(\.units)
        XCTAssertEqual(units, stride(from: 0.5, through: 20, by: 0.5).map { $0 })
    }

    /// A number spoken at Siri's follow-up question must still land on the half-unit list, or be refused.
    func testSpokenUnitsMapOnlyToListedAmounts() {
        XCTAssertEqual(BolusAmount(units: 1.5), .units1_5)
        XCTAssertEqual(BolusAmount(units: 20), .units20)
        for invalid in [0, 1.3, 20.5, -1] {
            XCTAssertNil(BolusAmount(units: invalid), "\(invalid) must not be logged")
        }
    }

    /// A Siri bolus is the same record as one added in the treatment editor, queued for Nightscout.
    @MainActor func testRecordedBolusIsAnInsulinTreatmentAwaitingUpload() throws {
        try withRestoredDefaults {
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = nil
            UserDefaults.standard.nightscoutSyncRequired = false
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let date = Date(timeIntervalSince1970: 1_790_000_000)

            try LogBolusIntent.recordBolus(.units1_5, at: date, coreDataManager: coreDataManager)

            let saved = try XCTUnwrap(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).first)
            XCTAssertEqual(saved.treatmentType, .Insulin)
            XCTAssertEqual(saved.value, 1.5)
            XCTAssertEqual(saved.date, date)
            XCTAssertEqual(saved.enteredBy, ConstantsHomeView.applicationName)
            XCTAssertFalse(saved.uploaded)
            XCTAssertTrue(UserDefaults.standard.nightscoutSyncRequired)
        }
    }

    /// The Home chart observes this counter, so a bolus logged while the app is open appears at once.
    @MainActor func testRecordedBolusRefreshesTheChart() throws {
        try withRestoredDefaults {
            let before = UserDefaults.standard.nightscoutTreatmentsUpdateCounter
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)

            try LogBolusIntent.recordBolus(.units2, at: Date(), coreDataManager: coreDataManager)

            XCTAssertEqual(UserDefaults.standard.nightscoutTreatmentsUpdateCounter, before + 1)
        }
    }

    /// Logging from a locked phone is refused unless the user opted in; an unlocked phone always logs.
    func testLockedPhoneRefusesBolusUnlessAllowedInSettings() {
        XCTAssertTrue(LogBolusIntent.isRefusedWhileLocked(allowedWhenLocked: false, isDeviceUnlocked: false))
        XCTAssertFalse(LogBolusIntent.isRefusedWhileLocked(allowedWhenLocked: true, isDeviceUnlocked: false))
        XCTAssertFalse(LogBolusIntent.isRefusedWhileLocked(allowedWhenLocked: false, isDeviceUnlocked: true))
    }

    /// Siri bolus logging from a locked phone must be an explicit choice, never the default.
    func testLockedLoggingIsOffByDefault() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        XCTAssertFalse(defaults.allowSiriBolusWhenLocked)
    }

    /// The locked-logging choice lives in Treatment settings next to the other insulin options.
    @MainActor func testTreatmentSettingsToggleControlsLockedLogging() throws {
        try withRestoredDefaults {
            let row = try XCTUnwrap(TreatmentSettingsViewModel(group: .siriBolus).settingsRows(sectionID: 0).first)
            guard case .toggle(let isOn, let setIsOn, _) = row.control else {
                return XCTFail("Expected a toggle, found \(String(describing: row.control))")
            }

            setIsOn(true)
            XCTAssertTrue(UserDefaults.standard.allowSiriBolusWhenLocked)
            XCTAssertTrue(isOn())
            setIsOn(false)
            XCTAssertFalse(UserDefaults.standard.allowSiriBolusWhenLocked)
            XCTAssertFalse(isOn())
        }
    }

    @MainActor private func withRestoredDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let keys = [UserDefaults.Key.timeStampLatestNightscoutSyncRequest, .nightscoutSyncRequired, .nightscoutTreatmentsUpdateCounter, .allowSiriBolusWhenLocked].map(\.rawValue)
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        try body()
    }
}
