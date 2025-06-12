import UIKit

fileprivate enum Setting: Int, CaseIterable {
    
    // appearance settings
    case appIcon = 0
    
}

/// view model for Settings General
class SettingsViewAppearanceSettingsViewModel:SettingsViewModelProtocol {
    
    /// for section General Settings, the number of rows
    func numberOfRows() -> Int {
        
        // the number of settings in the enum
        return Setting.allCases.count
    }
    
    /// the only purpose of this closure is to be able to call it from inside an asynchronous completion block
    private var sectionReloadClosure: (() -> Void)?
    
    /// message handler
    private var messageHandler: ((String, String) -> Void)?
    
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected row in SettingsViewAppearanceSettingsViewModel onRowSelect") }
        
        switch setting {
            
        case .appIcon:
            // Get available icon names from Info.plist
            let availableIcons = getAvailableIconNames()
            let currentIcon = UserDefaults.standard.selectedAppIcon
            
            // Find current selection index
            var selectedIndex = 0
            if let currentIcon = currentIcon {
                selectedIndex = availableIcons.firstIndex(of: currentIcon) ?? 0
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.selectAppIcon, data: getIconDisplayNames(), selectedRow: selectedIndex, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                let selectedIconName = index == 0 ? nil : availableIcons[index]
                
                // Store the selection
                UserDefaults.standard.selectedAppIcon = selectedIconName
                
                // Change the app icon
                UIApplication.shared.setAlternateIconName(selectedIconName) { error in
                    if let error = error {
                            if let messageHandler = self.messageHandler {
                        messageHandler(Texts_Common.warning, error.localizedDescription)
                    }
                    }
                }
                
                // reload the section to update the current value
                self.sectionReloadClosure?()
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.appearanceSettingsIcon + " " + Texts_SettingsView.sectionTitleAppearance
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return Setting.allCases.count
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected row in SettingsViewAppearanceSettingsViewModel settingsRowText") }
        
        switch setting {
            
        case .appIcon:
            return Texts_SettingsView.labelAppIcon
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected row in SettingsViewAppearanceSettingsViewModel accessoryType") }
        
        switch setting {
            
        case .appIcon:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected row in SettingsViewAppearanceSettingsViewModel detailedText") }
        
        switch setting {
            
        case .appIcon:
            if let selectedIcon = UserDefaults.standard.selectedAppIcon {
                return getDisplayNameForIcon(selectedIcon)
            } else {
                return getDisplayNameForIcon(nil)
            }
            
        }
    }
    
    func uiView(index: Int) -> UIView? {
        return nil
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    // MARK: - UITableViewDataSource protocol Methods
    
    func storeUIViewController(uIViewController: UIViewController) {
        // not used in this viewmodel
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {
        // not used in this viewmodel
    }
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    // MARK: - Private helper methods
    
    private func getAvailableIconNames() -> [String] {
        // First item is default (nil), rest are alternate icon names
        return ["", "AppIcon-Cyborg-Classic", "AppIcon-Cyborg-Dark", "AppIcon-Cyborg-Blue", "AppIcon-Cyborg-Red"]
    }
    
    private func getIconDisplayNames() -> [String] {
        return [Texts_SettingsView.appIconDefault, 
                Texts_SettingsView.appIconCyborgClassic,
                Texts_SettingsView.appIconCyborgDark,
                Texts_SettingsView.appIconCyborgBlue,
                Texts_SettingsView.appIconCyborgRed]
    }
    
    private func getDisplayNameForIcon(_ iconName: String?) -> String {
        guard let iconName = iconName else {
            return Texts_SettingsView.appIconDefault
        }
        
        switch iconName {
        case "AppIcon-Cyborg-Classic":
            return Texts_SettingsView.appIconCyborgClassic
        case "AppIcon-Cyborg-Dark":
            return Texts_SettingsView.appIconCyborgDark
        case "AppIcon-Cyborg-Blue":
            return Texts_SettingsView.appIconCyborgBlue
        case "AppIcon-Cyborg-Red":
            return Texts_SettingsView.appIconCyborgRed
        default:
            return Texts_SettingsView.appIconDefault
        }
    }
}