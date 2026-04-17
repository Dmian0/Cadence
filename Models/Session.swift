import Foundation

struct Session: Codable, Identifiable {
    let id: UUID
    let mode: SessionMode
    let startedAt: Date
    var endedAt: Date?
    var iterationCount: Int
    var wasCompleted: Bool   // did the full duration, not skipped

    // Sub-session hierarchy
    var isSubSession: Bool
    var parentSessionId: UUID?
    var subSessions: [Session]

    init(mode: SessionMode, parentId: UUID? = nil) {
        self.id              = UUID()
        self.mode            = mode
        self.startedAt       = Date()
        self.endedAt         = nil
        self.iterationCount  = 0
        self.wasCompleted    = false
        self.isSubSession    = parentId != nil
        self.parentSessionId = parentId
        self.subSessions     = []
    }

    // Custom decoder for backward compatibility with persisted sessions
    // that don't have the new sub-session fields
    enum CodingKeys: String, CodingKey {
        case id, mode, startedAt, endedAt, iterationCount, wasCompleted,
             isSubSession, parentSessionId, subSessions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self, forKey: .id)
        mode            = try c.decode(SessionMode.self, forKey: .mode)
        startedAt       = try c.decode(Date.self, forKey: .startedAt)
        endedAt         = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        iterationCount  = try c.decode(Int.self, forKey: .iterationCount)
        wasCompleted    = try c.decode(Bool.self, forKey: .wasCompleted)
        isSubSession    = try c.decodeIfPresent(Bool.self, forKey: .isSubSession) ?? false
        parentSessionId = try c.decodeIfPresent(UUID.self, forKey: .parentSessionId)
        subSessions     = try c.decodeIfPresent([Session].self, forKey: .subSessions) ?? []
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    // Contribution to today's flow score
    var scoreContribution: Double {
        guard wasCompleted else { return mode.scoreWeight * 0.3 }
        return mode.scoreWeight
    }

    // Close this session. Sets endedAt and computes wasCompleted from duration.
    // Threshold: duration >= configured mode duration * 0.8.
    // If completed=false (explicit skip), always marks wasCompleted=false.
    mutating func markEnded(completed: Bool) {
        endedAt = Date()
        guard completed else {
            wasCompleted = false
            return
        }
        let target = Double(mode.duration)
        wasCompleted = duration >= target * 0.8
    }
}

// MARK: - DayRecord  (what gets persisted per calendar day)
struct DayRecord: Codable {
    var date: Date
    var sessions: [Session]
    var streak: Int

    // Flatten top-level + nested sub-sessions (for duration-based stats)
    private var allSessionsFlat: [Session] {
        sessions + sessions.flatMap { $0.subSessions }
    }

    // 6-second floor filters tap-accident sub-sessions out of duration stats
    private var countableSessions: [Session] {
        allSessionsFlat.filter { $0.duration >= 6 }
    }

    // Flow score 0–100 (only parent/independent sessions count)
    var flowScore: Int {
        let parentSessions = sessions.filter { !$0.isSubSession }
        let raw = parentSessions.reduce(0.0) { $0 + $1.scoreContribution }
        // 8 completed deep work sessions ≈ 100
        return min(100, Int((raw / 8.0) * 100))
    }

    var totalFocusTime: TimeInterval {
        countableSessions
            .filter { $0.mode == .deep || $0.mode == .review }
            .reduce(0) { $0 + $1.duration }
    }

    var totalAIWaitTime: TimeInterval {
        countableSessions
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
