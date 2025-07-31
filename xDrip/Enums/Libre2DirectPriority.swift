//
//  Libre2DirectPriority.swift
//  xdrip
//
//  Created for xDrip4iOS.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// Priority setting for Libre 2 direct connections when both iPhone and Watch are in range
enum Libre2DirectPriority: Int, CaseIterable {
    
    /// iPhone always has priority (default)
    case iPhone = 0
    
    /// Watch always has priority
    case watch = 1
    
    /// Auto - iPhone when screen is on/app is active, Watch otherwise
    case auto = 2
    
    var description: String {
        switch self {
        case .iPhone:
            return Texts_SettingsView.libre2DirectPriorityiPhone
        case .watch:
            return Texts_SettingsView.libre2DirectPriorityWatch
        case .auto:
            return Texts_SettingsView.libre2DirectPriorityAuto
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .iPhone:
            return Texts_SettingsView.libre2DirectPriorityiPhoneDescription
        case .watch:
            return Texts_SettingsView.libre2DirectPriorityWatchDescription
        case .auto:
            return Texts_SettingsView.libre2DirectPriorityAutoDescription
        }
    }
}

extension UserDefaults {
    
    /// Libre 2 direct connection priority
    var libre2DirectPriority: Libre2DirectPriority {
        get {
            return Libre2DirectPriority(rawValue: integer(forKey: "libre2DirectPriority")) ?? .iPhone
        }
        set {
            set(newValue.rawValue, forKey: "libre2DirectPriority")
        }
    }
    
    /// Is Watch direct connection enabled
    @objc dynamic var libre2DirectToWatchEnabled: Bool {
        get {
            return bool(forKey: "libre2DirectToWatchEnabled")
        }
        set {
            set(newValue, forKey: "libre2DirectToWatchEnabled")
        }
    }
}