import Foundation

// Simplified JSON protocol for xDripSwift
protocol JSON: Codable {
    var rawJSON: String { get }
    init?(from rawJSON: String)
}

extension JSON {
    var rawJSON: String {
        do {
            let data = try JSONCoding.encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    init?(from rawJSON: String) {
        guard let data = rawJSON.data(using: .utf8) else {
            return nil
        }
        
        do {
            let object = try JSONCoding.decoder.decode(Self.self, from: data)
            self = object
        } catch {
            // Log error using xDripSwift's trace function if needed
            return nil
        }
    }
}

typealias RawJSON = String

extension RawJSON {
    static let null = "null"
    static let empty = ""
}

// JSONCoding helper
enum JSONCoding {
    static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .formatted(iso8601Formatter)
        return encoder
    }
    
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(iso8601Formatter)
        return decoder
    }
}