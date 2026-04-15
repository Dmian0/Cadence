import Foundation

final class DayStore {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var sessionsKey: String {
        "cadence_sessions_\(todayDateKey)"
    }
    private let streakKey = "cadence_streak"

    private var todayDateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Load

    func loadToday() -> DayRecord {
        let sessions = loadSessions()
        let streak   = UserDefaults.standard.integer(forKey: streakKey)
        return DayRecord(date: Date(), sessions: sessions, streak: streak)
    }

    // MARK: - Save

    func save(sessions: [Session], streak: Int) {
        if let data = try? encoder.encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
        UserDefaults.standard.set(streak, forKey: streakKey)
    }

    // MARK: - Private

    private func loadSessions() -> [Session] {
        guard
            let data     = UserDefaults.standard.data(forKey: sessionsKey),
            let sessions = try? decoder.decode([Session].self, from: data)
        else { return [] }
        return sessions
    }
}
