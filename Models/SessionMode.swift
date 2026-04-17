import SwiftUI

enum SessionMode: String, CaseIterable, Codable {
    case deep    = "deep"
    case aiWait  = "aiWait"
    case review  = "review"
    case rest    = "rest"

    var label: String {
        switch self {
        case .deep:   return NSLocalizedString("deep_work", comment: "")
        case .aiWait: return NSLocalizedString("ai_wait", comment: "")
        case .review: return NSLocalizedString("review", comment: "")
        case .rest:   return NSLocalizedString("break_mode", comment: "")
        }
    }

    var duration: Int {  // seconds (configurable via SettingsStore)
        SettingsStore.shared.durationSeconds(for: self)
    }

    // Flow score weight — deep work is worth more than passive states
    var scoreWeight: Double {
        switch self {
        case .deep:   return 1.0
        case .review: return 0.5
        case .aiWait: return 0.2
        case .rest:   return 0.0
        }
    }

    var color: Color {
        switch self {
        case .deep:   return Color(hex: "#7F77DD")
        case .aiWait: return Color(hex: "#1D9E75")
        case .review: return Color(hex: "#EF9F27")
        case .rest:   return Color(hex: "#378ADD")
        }
    }

    var lightBackground: Color {
        switch self {
        case .deep:   return Color(hex: "#EEEDFE")
        case .aiWait: return Color(hex: "#E1F5EE")
        case .review: return Color(hex: "#FAEEDA")
        case .rest:   return Color(hex: "#E6F1FB")
        }
    }

    var sfSymbol: String {
        switch self {
        case .deep:   return "bolt.fill"
        case .aiWait: return "hourglass"
        case .review: return "eye.fill"
        case .rest:   return "cloud.fill"
        }
    }

    var emoji: String {
        switch self {
        case .deep:   return "⚡"
        case .aiWait: return "⏳"
        case .review: return "👁"
        case .rest:   return "☁"
        }
    }

    // Whether this mode counts toward break debt
    var countsAsWork: Bool {
        switch self {
        case .deep, .aiWait, .review: return true
        case .rest: return false
        }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
