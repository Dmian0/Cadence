import Foundation

struct Session: Codable, Identifiable {
    let id: UUID
    let mode: SessionMode
    let startedAt: Date
    var endedAt: Date?
    var iterationCount: Int
    var wasCompleted: Bool   // did the full duration, not skipped

    init(mode: SessionMode) {
        self.id             = UUID()
        self.mode           = mode
        self.startedAt      = Date()
        self.endedAt        = nil
        self.iterationCount = 0
        self.wasCompleted   = false
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    // Contribution to today's flow score
    var scoreContribution: Double {
        guard wasCompleted else { return mode.scoreWeight * 0.3 }
        return mode.scoreWeight
    }
}

// MARK: - DayRecord  (what gets persisted per calendar day)
struct DayRecord: Codable {
    var date: Date
    var sessions: [Session]
    var streak: Int

    // Flow score 0–100
    var flowScore: Int {
        let raw = sessions.reduce(0.0) { $0 + $1.scoreContribution }
        // 8 completed deep work sessions ≈ 100
        return min(100, Int((raw / 8.0) * 100))
    }

    var totalFocusTime: TimeInterval {
        sessions
            .filter { $0.mode == .deep || $0.mode == .review }
            .reduce(0) { $0 + $1.duration }
    }

    var totalAIWaitTime: TimeInterval {
        sessions
            .filter { $0.mode == .aiWait }
            .reduce(0) { $0 + $1.duration }
    }

    var completionRate: Int {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter { $0.wasCompleted }.count
        return Int(Double(completed) / Double(sessions.count) * 100)
    }

    // Sessions since last rest — drives break debt
    var workSessionsSinceBreak: Int {
        var count = 0
        for session in sessions.reversed() {
            if session.mode == .rest { break }
            if session.mode.countsAsWork { count += 1 }
        }
        return count
    }
}
