import Foundation

enum AppVersion {
    static var short: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        return "0.0.0"
    }

    static var display: String {
        short.hasPrefix("v") ? short : "v\(short)"
    }
}
