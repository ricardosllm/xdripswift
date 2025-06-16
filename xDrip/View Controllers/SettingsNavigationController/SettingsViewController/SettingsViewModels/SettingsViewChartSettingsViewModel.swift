import Foundation
import UIKit

/// View model for chart settings
struct SettingsViewChartSettingsViewModel: SettingsViewModelProtocol {
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.chartSettingsIcon + " " + Texts_SettingsView.labelChartSettings
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return Texts_SettingsView.labelShowTreatmentsOnChart
        case .showIOBCOBOnChart:
            return "Show IOB/COB Values"
        case .showIOBTrendOnChart:
            return "Show IOB Trend Line"
        case .showCOBTrendOnChart:
            return "Show COB Trend Line"
        case .showIAPSPredictions:
            return "Enable iAPS Predictions"
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return Texts_SettingsView.descriptionShowTreatmentsOnChart
        case .showIOBCOBOnChart:
            return "Display IOB and COB values on main chart"
        case .showIOBTrendOnChart:
            return "Show IOB decay as a trend line"
        case .showCOBTrendOnChart:
            return "Show COB absorption as a trend line"
        case .showIAPSPredictions:
            return "Show iAPS algorithm predictions on chart"
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return UserDefaults.standard.showTreatmentsOnChart ? .checkmark : .none
        case .showIOBCOBOnChart:
            return UserDefaults.standard.showIOBCOBOnChart ? .checkmark : .none
        case .showIOBTrendOnChart:
            return UserDefaults.standard.showIOBTrendOnChart ? .checkmark : .none
        case .showCOBTrendOnChart:
            return UserDefaults.standard.showCOBTrendOnChart ? .checkmark : .none
        case .showIAPSPredictions:
            return UserDefaults.standard.showIAPSPredictions ? .checkmark : .none
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return .callFunction {
                UserDefaults.standard.showTreatmentsOnChart.toggle()
            }
        case .showIOBCOBOnChart:
            return .callFunction {
                UserDefaults.standard.showIOBCOBOnChart.toggle()
            }
        case .showIOBTrendOnChart:
            return .callFunction {
                UserDefaults.standard.showIOBTrendOnChart.toggle()
            }
        case .showCOBTrendOnChart:
            return .callFunction {
                UserDefaults.standard.showCOBTrendOnChart.toggle()
            }
        case .showIAPSPredictions:
            return .callFunction {
                UserDefaults.standard.showIAPSPredictions.toggle()
            }
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
}

// MARK: - Private Enums

extension SettingsViewChartSettingsViewModel {
    
    private enum Setting: Int, CaseIterable {
        case showTreatmentsOnChart = 0
        case showIOBCOBOnChart = 1
        case showIOBTrendOnChart = 2
        case showCOBTrendOnChart = 3
        case showIAPSPredictions = 4
    }
}