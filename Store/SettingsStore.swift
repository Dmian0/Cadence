import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let durationDeep   = "cadence_duration_deep"
        static let durationAIWait = "cadence_duration_aiWait"
        static let durationReview = "cadence_duration_review"
        static let durationRest   = "cadence_duration_rest"
    }

    private static let defaultMinutes: [String: Int] = [
        Key.durationDeep:   25,
        Key.durationAIWait: 5,
        Key.durationReview: 10,
        Key.durationRest:   5,
    ]

    func durationSeconds(for mode: SessionMode) -> Int {
        let key = storageKey(for: mode)
        let minutes: Int
        if defaults.object(forKey: key) != nil {
            minutes = defaults.integer(forKey: key)
        } else {
            minutes = Self.defaultMinutes[key]!
        }
        return minutes * 60
    }

    func setDurationMinutes(_ minutes: Int, for mode: SessionMode) {
        defaults.set(minutes, forKey: storageKey(for: mode))
    }

    private func storageKey(for mode: SessionMode) -> String {
        switch mode {
        case .deep:   return Key.durationDeep
        case .aiWait: return Key.durationAIWait
        case .review: return Key.durationReview
        case .rest:   return Key.durationRest
        }
    }
}
