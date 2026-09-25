//
//  LogBolusIntent.swift
//  xdrip
//
//  Created by Ricardo Mota on 25/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AppIntents
import Foundation
import OSLog
import UIKit

/// The bolus amounts Siri can log, in half-unit steps up to a 20 U ceiling.
///
/// App Shortcut phrases only accept entity or enum parameters, so a spoken amount is matched
/// against this list instead of a free number. The list doubles as the maximum Siri can record.
/// Titles are bare numbers so they match Siri's digit transcription of a spoken amount; per-case spoken
/// synonyms would need iOS 17. They must stay literal as App Intents metadata is extracted at build time.
enum BolusAmount: String, AppEnum {
    case units0_5 = "0.5"
    case units1 = "1"
    case units1_5 = "1.5"
    case units2 = "2"
    case units2_5 = "2.5"
    case units3 = "3"
    case units3_5 = "3.5"
    case units4 = "4"
    case units4_5 = "4.5"
    case units5 = "5"
    case units5_5 = "5.5"
    case units6 = "6"
    case units6_5 = "6.5"
    case units7 = "7"
    case units7_5 = "7.5"
    case units8 = "8"
    case units8_5 = "8.5"
    case units9 = "9"
    case units9_5 = "9.5"
    case units10 = "10"
    case units10_5 = "10.5"
    case units11 = "11"
    case units11_5 = "11.5"
    case units12 = "12"
    case units12_5 = "12.5"
    case units13 = "13"
    case units13_5 = "13.5"
    case units14 = "14"
    case units14_5 = "14.5"
    case units15 = "15"
    case units15_5 = "15.5"
    case units16 = "16"
    case units16_5 = "16.5"
    case units17 = "17"
    case units17_5 = "17.5"
    case units18 = "18"
    case units18_5 = "18.5"
    case units19 = "19"
    case units19_5 = "19.5"
    case units20 = "20"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bolus Amount"

    static var caseDisplayRepresentations: [BolusAmount: DisplayRepresentation] = [
        .units0_5: DisplayRepresentation(title: "0.5"),
        .units1: DisplayRepresentation(title: "1"),
        .units1_5: DisplayRepresentation(title: "1.5"),
        .units2: DisplayRepresentation(title: "2"),
        .units2_5: DisplayRepresentation(title: "2.5"),
        .units3: DisplayRepresentation(title: "3"),
        .units3_5: DisplayRepresentation(title: "3.5"),
        .units4: DisplayRepresentation(title: "4"),
        .units4_5: DisplayRepresentation(title: "4.5"),
        .units5: DisplayRepresentation(title: "5"),
        .units5_5: DisplayRepresentation(title: "5.5"),
        .units6: DisplayRepresentation(title: "6"),
        .units6_5: DisplayRepresentation(title: "6.5"),
        .units7: DisplayRepresentation(title: "7"),
        .units7_5: DisplayRepresentation(title: "7.5"),
        .units8: DisplayRepresentation(title: "8"),
        .units8_5: DisplayRepresentation(title: "8.5"),
        .units9: DisplayRepresentation(title: "9"),
        .units9_5: DisplayRepresentation(title: "9.5"),
        .units10: DisplayRepresentation(title: "10"),
        .units10_5: DisplayRepresentation(title: "10.5"),
        .units11: DisplayRepresentation(title: "11"),
        .units11_5: DisplayRepresentation(title: "11.5"),
        .units12: DisplayRepresentation(title: "12"),
        .units12_5: DisplayRepresentation(title: "12.5"),
        .units13: DisplayRepresentation(title: "13"),
        .units13_5: DisplayRepresentation(title: "13.5"),
        .units14: DisplayRepresentation(title: "14"),
        .units14_5: DisplayRepresentation(title: "14.5"),
        .units15: DisplayRepresentation(title: "15"),
        .units15_5: DisplayRepresentation(title: "15.5"),
        .units16: DisplayRepresentation(title: "16"),
        .units16_5: DisplayRepresentation(title: "16.5"),
        .units17: DisplayRepresentation(title: "17"),
        .units17_5: DisplayRepresentation(title: "17.5"),
        .units18: DisplayRepresentation(title: "18"),
        .units18_5: DisplayRepresentation(title: "18.5"),
        .units19: DisplayRepresentation(title: "19"),
        .units19_5: DisplayRepresentation(title: "19.5"),
        .units20: DisplayRepresentation(title: "20"),
    ]

    /// Insulin units as stored in a treatment.
    var units: Double {
        Double(rawValue) ?? 0
    }

    /// The listed amount for a number Siri heard, or nil when it is off the half-unit grid or above 20 U.
    init?(units: Double) {
        guard let amount = Self.allCases.first(where: { $0.units == units }) else { return nil }
        self = amount
    }
}

/// Logs a bolus spoken to Siri, such as "Log 1.5 bolus in xDrip", after reading the amount back.
///
/// When the phrase has no amount, Siri asks for a number rather than the list, which it would read aloud in full. The saved treatment is the same insulin entry
/// the treatment editor creates, so IOB, the Home chart and Nightscout treat it identically.
struct LogBolusIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Bolus"
    static var description = IntentDescription("Record a bolus insulin treatment in half-unit steps up to 20 units.", categoryName: "Treatments")
    static var openAppWhenRun = false

    /// The policy must be a build-time constant, so the user's lock preference is enforced in perform().
    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    /// Filled by one-shot phrases such as "Log 2 bolus in xDrip".
    @Parameter(title: "Amount")
    var amount: BolusAmount?

    /// Asked for only when the phrase had no amount.
    @Parameter(title: "Units", requestValueDialog: "How many units?")
    var spokenUnits: Double?

    private static let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataTreatments)

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Siri cannot show an unlock prompt for a runtime setting, so a locked phone is refused with a spoken reason.
        if Self.isRefusedWhileLocked(allowedWhenLocked: UserDefaults.standard.allowSiriBolusWhenLocked, isDeviceUnlocked: UIApplication.shared.isProtectedDataAvailable) {
            throw IntentError.message("Unlock your iPhone to log a bolus.")
        }

        let amount = try await resolvedAmount()

        // A misheard amount must never be stored silently: Siri reads the matched value back first.
        guard try await $amount.requestConfirmation(for: amount, dialog: "Log \(amount.rawValue) units of bolus insulin?") else {
            return .result(dialog: "OK, no bolus logged.")
        }

        let coreDataManager = await IntentCoreData.sharedManager()
        try Self.recordBolus(amount, at: Date(), coreDataManager: coreDataManager)

        return .result(dialog: "Logged \(amount.rawValue) units of bolus insulin.")
    }

    private func resolvedAmount() async throws -> BolusAmount {
        if let amount {
            return amount
        }

        let units: Double
        if let spokenUnits {
            units = spokenUnits
        } else {
            units = try await $spokenUnits.requestValue()
        }

        guard let amount = BolusAmount(units: units) else {
            throw IntentError.message("Siri can log a bolus from 0.5 to 20 units, in half-unit steps.")
        }
        return amount
    }

    /// A locked phone only records a bolus when the user has explicitly allowed it.
    static func isRefusedWhileLocked(allowedWhenLocked: Bool, isDeviceUnlocked: Bool) -> Bool {
        !allowedWhenLocked && !isDeviceUnlocked
    }

    /// Stores the bolus as a new insulin treatment and queues it for Nightscout like an editor save.
    @MainActor
    static func recordBolus(_ amount: BolusAmount, at date: Date, coreDataManager: CoreDataManager) throws {
        let treatment = TreatmentEntry(
            date: date,
            value: amount.units,
            treatmentType: .Insulin,
            nightscoutEventType: nil,
            enteredBy: ConstantsHomeView.applicationName,
            nsManagedObjectContext: coreDataManager.mainManagedObjectContext
        )

        // Siri may launch the app in the background and suspend it right after perform() returns,
        // so the bolus must reach the store before the intent reports success.
        guard coreDataManager.saveChangesSynchronously() else {
            // Otherwise the next successful save anywhere in the app would store a bolus Siri reported as failed.
            coreDataManager.mainManagedObjectContext.delete(treatment)
            trace("failed to save a Siri bolus", log: log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error)
            throw IntentError.message("The bolus could not be saved.")
        }

        // Match the editor's shareable trace: only the treatment kind and date, never the amount.
        trace(
            "added %{public}@ treatment at %{public}@ via Siri",
            log: log,
            category: ConstantsLog.categoryApplicationDataTreatments,
            type: .info,
            troubleshooting: .standard(.treatment(.added(
                kind: TroubleshootingTreatmentKind(TreatmentType.Insulin),
                treatmentAt: date
            ))),
            TreatmentType.Insulin.asString(),
            date.description
        )

        UserDefaults.standard.requestNightscoutTreatmentSync()

        // The Home chart reloads on this counter, so an open app shows the bolus without waiting for a reading.
        UserDefaults.standard.nightscoutTreatmentsUpdateCounter += 1
    }
}
