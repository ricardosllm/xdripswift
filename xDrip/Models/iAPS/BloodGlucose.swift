import Foundation

struct BloodGlucose: JSON, Identifiable, Hashable, Codable {
    enum Direction: String, Codable {
        case tripleUp = "TripleUp"
        case doubleUp = "DoubleUp"
        case singleUp = "SingleUp"
        case fortyFiveUp = "FortyFiveUp"
        case flat = "Flat"
        case fortyFiveDown = "FortyFiveDown"
        case singleDown = "SingleDown"
        case doubleDown = "DoubleDown"
        case tripleDown = "TripleDown"
        case none = "NONE"
        case notComputable = "NOT COMPUTABLE"
        case rateOutOfRange = "RATE OUT OF RANGE"
    }
    
    var _id = UUID().uuidString
    var id: String { _id }
    
    var sgv: Int?
    var direction: Direction?
    let date: Decimal
    let dateString: Date
    let unfiltered: Decimal?
    let filtered: Decimal?
    let noise: Int?
    var glucose: Int?
    let type: String?
    
    var isStateValid: Bool { sgv ?? 0 >= 39 && noise ?? 1 != 4 }
    
    static func == (lhs: BloodGlucose, rhs: BloodGlucose) -> Bool {
        lhs.dateString == rhs.dateString
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dateString)
    }
}

enum GlucoseUnits: String, Codable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"
    
    static let exchangeRate: Decimal = 0.0555
}