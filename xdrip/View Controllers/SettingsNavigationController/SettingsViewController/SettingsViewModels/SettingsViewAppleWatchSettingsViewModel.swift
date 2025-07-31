//
//  SettingsViewAppleWatchSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 21/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import OSLog

fileprivate enum Setting: Int, CaseIterable {
    // does the user agree to show data in the complications knowing that it will not always be up-to-date?
    case showDataInWatchComplications = 0
    
    /// the date that the user agreed
    case watchComplicationUserAgreementDate = 1
    
    /// enable Libre 2 direct connection to Apple Watch
    case libre2DirectToWatchEnabled = 2
    
    /// priority when both iPhone and Watch are in range
    case libre2DirectPriority = 3
    
    /// connection status info
    case libre2ConnectionStatus = 4
    
    /// button to scan sensor for watch handover
    case scanForWatchHandover = 5
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewAppleWatchSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel)
    
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    var sectionReloadClosure: (() -> Void)?
    
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        
        // unwrap messageHandler
        guard let messageHandler = messageHandler else {return}
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
        
    }
    
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications, .watchComplicationUserAgreementDate, .libre2ConnectionStatus, .scanForWatchHandover:
            return nil
            
        case .libre2DirectToWatchEnabled:
            return UISwitch(isOn: UserDefaults.standard.libre2DirectToWatchEnabled, action: { [weak self] isOn in
                UserDefaults.standard.libre2DirectToWatchEnabled = isOn
                
                // If enabling, post notification to share sensor data with Watch
                if isOn {
                    NotificationCenter.default.post(name: .libre2DirectConnectionEnabled, object: nil)
                }
                
                // Reload the section to update the priority row enable state
                self?.sectionReloadClosure?()
            })
            
        case .libre2DirectPriority:
            return nil
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func isEnabled(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .libre2DirectPriority, .scanForWatchHandover:
            // Only enable priority setting and scan button if direct connection is enabled
            return UserDefaults.standard.libre2DirectToWatchEnabled
            
        default:
            return true
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
                return .askConfirmation(title: Texts_SettingsView.appleWatchShowDataInComplications, message: Texts_SettingsView.appleWatchShowDataInComplicationsMessage, actionHandler: {
                    UserDefaults.standard.showDataInWatchComplications = true
                    UserDefaults.standard.watchComplicationUserAgreementDate = .now
                }, cancelHandler: {
                    UserDefaults.standard.showDataInWatchComplications = false
                    UserDefaults.standard.watchComplicationUserAgreementDate = nil
                    // we have to run this in the main thread to avoid access errors
                    DispatchQueue.main.async {
                        self.sectionReloadClosure?()
                    }
                })
            
        case .watchComplicationUserAgreementDate:
            return .nothing
            
        case .libre2DirectToWatchEnabled:
            return .nothing
            
        case .libre2DirectPriority:
            return .callFunction {
                // Cycle through the priorities
                let currentPriority = UserDefaults.standard.libre2DirectPriority
                let allCases = Libre2DirectPriority.allCases
                if let currentIndex = allCases.firstIndex(of: currentPriority) {
                    let nextIndex = (currentIndex + 1) % allCases.count
                    UserDefaults.standard.libre2DirectPriority = allCases[nextIndex]
                }
            }
            
        case .libre2ConnectionStatus:
            return .nothing
            
        case .scanForWatchHandover:
            return .callFunction { [weak self] in
                self?.handleScanForWatchHandover()
            }
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.appleWatchSettingsIcon + " " + Texts_SettingsView.appleWatchSectionTitle
    }
    
    func numberOfRows() -> Int {
        // Show all settings except hide the complication date if complications are disabled
        return Setting.allCases.count - (UserDefaults.standard.showDataInWatchComplications ? 0 : 1)
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return Texts_SettingsView.appleWatchShowDataInComplications
            
        case .watchComplicationUserAgreementDate:
            return Texts_SettingsView.appleWatchComplicationUserAgreementDate
            
        case .libre2DirectToWatchEnabled:
            return Texts_SettingsView.libre2DirectToWatchEnabled
            
        case .libre2DirectPriority:
            return Texts_SettingsView.libre2DirectPriority
            
        case .libre2ConnectionStatus:
            return Texts_SettingsView.libre2ConnectionStatus
            
        case .scanForWatchHandover:
            return "Scan Sensor for Watch Handover"
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return .disclosureIndicator
            
        case .watchComplicationUserAgreementDate, .libre2ConnectionStatus:
            return .none
            
        case .libre2DirectToWatchEnabled:
            return .none
            
        case .libre2DirectPriority:
            return .disclosureIndicator
            
        case .scanForWatchHandover:
            return .disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDataInWatchComplications:
            return UserDefaults.standard.showDataInWatchComplications ? Texts_Common.enabled : Texts_Common.disabled
            
        case .watchComplicationUserAgreementDate:
            return UserDefaults.standard.watchComplicationUserAgreementDate?.formatted(date: .abbreviated, time: .shortened) ?? "-"
            
        case .libre2DirectToWatchEnabled:
            return UserDefaults.standard.libre2DirectToWatchEnabled ? Texts_Common.enabled : Texts_Common.disabled
            
        case .libre2DirectPriority:
            return UserDefaults.standard.libre2DirectPriority.description
            
        case .libre2ConnectionStatus:
            // For now, just show if the feature is enabled
            // TODO: Implement actual connection status tracking
            if UserDefaults.standard.libre2DirectToWatchEnabled {
                return Texts_SettingsView.libre2DirectEnabledStatus
            } else {
                return Texts_SettingsView.libre2DirectDisabledStatus
            }
            
        case .scanForWatchHandover:
            return "Activate sensor BLE for Watch"
        }
    }
    
    // MARK: - Private Methods
    
    private func handleScanForWatchHandover() {
        // Post notification to trigger NFC scan for Watch handover
        NotificationCenter.default.post(name: .scanLibre2ForWatchHandover, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let libre2DirectConnectionEnabled = Notification.Name("libre2DirectConnectionEnabled")
    static let scanLibre2ForWatchHandover = Notification.Name("scanLibre2ForWatchHandover")
}
