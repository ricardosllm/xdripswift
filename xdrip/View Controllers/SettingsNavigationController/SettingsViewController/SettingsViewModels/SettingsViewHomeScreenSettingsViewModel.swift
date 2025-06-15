//
//  SettingsViewHomeScreenSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 09/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    // allow the homescreen to be show a landscape chart when rotated?
    case allowScreenRotation = 0
    
    // show a clock at the bottom of the home screen when the screen lock is activated?
    case showClockWhenScreenIsLocked = 1
    
    // type of semi-transparent dark overlay to cover the app when the screen is locked
    case screenLockDimmingType = 2
    
    // show a fixed scale mini-chart under the main scrollable chart?
    case showMiniChart = 3
    
    //urgent high value
    case urgentHighMarkValue = 4
    
    //high value
    case highMarkValue = 5
    
    //target value
    case targetMarkValue = 6
    
    //low value
    case lowMarkValue = 7
    
    //urgent low value
    case urgentLowMarkValue = 8
    
    // iAPS prediction settings
    case showIAPSPredictions = 9
    
    // iAPS prediction time horizon (hours)
    case iAPSPredictionHours = 10
    
    // show IOB/COB on chart
    case showIOBCOBOnChart = 11
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewHomeScreenSettingsViewModel:SettingsViewModelProtocol {
    
    /// for section reload
    private var sectionReloadClosure: (() -> Void)?
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .allowScreenRotation:
            return UISwitch(isOn: UserDefaults.standard.allowScreenRotation, action: {(isOn:Bool) in UserDefaults.standard.allowScreenRotation = isOn})
            
        case .showClockWhenScreenIsLocked:
            return UISwitch(isOn: UserDefaults.standard.showClockWhenScreenIsLocked, action: {(isOn:Bool) in UserDefaults.standard.showClockWhenScreenIsLocked = isOn})
            
        case .showMiniChart:
            return UISwitch(isOn: UserDefaults.standard.showMiniChart, action: {(isOn:Bool) in UserDefaults.standard.showMiniChart = isOn})
            
        case .showIAPSPredictions:
            return UISwitch(isOn: UserDefaults.standard.showIAPSPredictions, action: {(isOn:Bool) in 
                UserDefaults.standard.showIAPSPredictions = isOn
            })
            
        case .showIOBCOBOnChart:
            return UISwitch(isOn: UserDefaults.standard.showIOBCOBOnChart, action: {(isOn:Bool) in 
                UserDefaults.standard.showIOBCOBOnChart = isOn
            })
            
        case  .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .targetMarkValue, .lowMarkValue, .urgentLowMarkValue, .iAPSPredictionHours:
            return nil
            
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func isEnabled(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .iAPSPredictionHours:
            // Only enabled if iAPS predictions are on
            return UserDefaults.standard.showIAPSPredictions
        default:
            return true
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentHighMarkValue:String) in UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded = urgentHighMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .highMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .targetMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTargetValue, message: Texts_SettingsView.targetValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.targetMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultTargetMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(targetMarkValue:String) in UserDefaults.standard.targetMarkValueInUserChosenUnitRounded = targetMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .lowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .urgentLowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentLowMarkValue:String) in UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded = urgentLowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .allowScreenRotation:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.allowScreenRotation {
                    UserDefaults.standard.allowScreenRotation = false
                } else {
                    UserDefaults.standard.allowScreenRotation = true
                }
            })
            
        case .showClockWhenScreenIsLocked:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showClockWhenScreenIsLocked {
                    UserDefaults.standard.showClockWhenScreenIsLocked = false
                } else {
                    UserDefaults.standard.showClockWhenScreenIsLocked = true
                }
            })
            
        case .screenLockDimmingType:
            
            // data to be displayed in list from which user needs to pick a screen dimming type
            var data = [String]()

            var selectedRow: Int?

            var index = 0
            
            let currentScreenLockDimmingType = UserDefaults.standard.screenLockDimmingType
            
            // get all data source types and add the description to data. Search for the type that matches the ScreenLockDimmingType that is currently stored in userdefaults.
            for dimmingType in ScreenLockDimmingType.allCases {
                
                data.append(dimmingType.description)
                
                if dimmingType == currentScreenLockDimmingType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.screenLockDimmingTypeWhenScreenIsLocked, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    
                    UserDefaults.standard.screenLockDimmingType = ScreenLockDimmingType(rawValue: index) ?? .disabled
                    
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .showMiniChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showMiniChart {
                    UserDefaults.standard.showMiniChart = false
                } else {
                    UserDefaults.standard.showMiniChart = true
                }
            })
            
        case .showIAPSPredictions:
            return SettingsSelectedRowAction.callFunction(function: { [weak self] in
                if UserDefaults.standard.showIAPSPredictions {
                    UserDefaults.standard.showIAPSPredictions = false
                } else {
                    UserDefaults.standard.showIAPSPredictions = true
                }
                // reload section to update enabled state of prediction hours row
                self?.sectionReloadClosure?()
            })
            
        // These cases are deprecated and handled in MDI settings
            
        case .iAPSPredictionHours:
            return SettingsSelectedRowAction.askText(
                title: "Prediction Time",
                message: "How many hours of predictions to show on the chart (0.5 - 4 hours)",
                keyboardType: .decimalPad,
                text: String(format: "%.1f", UserDefaults.standard.iAPSPredictionHours),
                placeHolder: "1.5",
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(valueAsString: String) in
                    if let value = Double(valueAsString), value >= 0.5, value <= 4.0 {
                        UserDefaults.standard.iAPSPredictionHours = value
                    }
                },
                cancelHandler: nil,
                inputValidator: { text in
                    guard let value = Double(text), value >= 0.5, value <= 4.0 else {
                        return "Please enter a value between 0.5 and 4 hours"
                    }
                    return nil
                }
            )
            
        case .showIOBCOBOnChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showIOBCOBOnChart {
                    UserDefaults.standard.showIOBCOBOnChart = false
                } else {
                    UserDefaults.standard.showIOBCOBOnChart = true
                }
            })
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.homeScreenSettingsIcon + " " + Texts_SettingsView.sectionTitleHomeScreen
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .allowScreenRotation:
            return Texts_SettingsView.allowScreenRotation
            
        case .showClockWhenScreenIsLocked:
            return Texts_SettingsView.showClockWhenScreenIsLocked
            
        case .screenLockDimmingType:
            return Texts_SettingsView.screenLockDimmingTypeWhenScreenIsLocked
            
        case .showMiniChart:
            return Texts_SettingsView.showMiniChart
            
        case .urgentHighMarkValue:
            return "🔴 " + Texts_SettingsView.labelUrgentHighValue
            
        case .highMarkValue:
            return "🟡 " + Texts_SettingsView.labelHighValue
            
        case .targetMarkValue:
            return "🟢 " + Texts_SettingsView.labelTargetValue
            
        case .lowMarkValue:
            return "🟡 " + Texts_SettingsView.labelLowValue
            
        case .urgentLowMarkValue:
            return "🔴 " + Texts_SettingsView.labelUrgentLowValue
            
        case .showIAPSPredictions:
            return "Show iAPS Predictions"
            
        // Deprecated - handled in MDI settings
            
        case .iAPSPredictionHours:
            return "Prediction Time Horizon"
            
        case .showIOBCOBOnChart:
            return "Show IOB/COB Values"
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .lowMarkValue, .urgentLowMarkValue, .targetMarkValue, .iAPSPredictionHours:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .showIAPSPredictions, .showIOBCOBOnChart:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .highMarkValue:
            return UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .targetMarkValue:
            return UserDefaults.standard.targetMarkValueInUserChosenUnit == 0 ? Texts_Common.disabled : UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .urgentLowMarkValue:
            return UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .screenLockDimmingType:
            return UserDefaults.standard.screenLockDimmingType.description
            
        case .iAPSPredictionHours:
            return String(format: "%.1f hours", UserDefaults.standard.iAPSPredictionHours)
            
        // Deprecated - handled in MDI settings
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .showIAPSPredictions, .showIOBCOBOnChart:
            return nil
            
        }
    }
    
}
