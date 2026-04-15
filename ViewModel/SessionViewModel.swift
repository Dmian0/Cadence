import Foundation
import Combine
import SwiftUI

@MainActor
final class SessionViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published private(set) var currentMode: SessionMode = .deep
    @Published private(set) var activeSession: Session?
    @Published var iterationCount: Int = 0
    @Published private(set) var showOverflowBanner: Bool = false

    // MARK: - Day data
    @Published private(set) var todaySessions: [Session] = []
    @Published private(set) var streak: Int = 0

    // MARK: - Sub-objects
    let timer = TimerEngine()

    // MARK: - Private
    private let store = DayStore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        loadToday()
        bindTimerEnd()
    }

    // MARK: - Mode

    func setMode(_ mode: SessionMode) {
        if activeSession != nil { endSession(completed: false) }
        currentMode = mode
        timer.load(seconds: mode.duration)
        iterationCount = 0
        showOverflowBanner = false
    }

    // MARK: - Session lifecycle

    func togglePlayPause() {
        if activeSession == nil {
            startSession()
        } else if timer.isRunning {
            timer.pause()
        } else {
            timer.start()
        }
    }

    func startSession() {
        let session = Session(mode: currentMode)
        activeSession  = session
        iterationCount = 0
        showOverflowBanner = false
        timer.load(seconds: currentMode.duration)
        timer.start()
    }

    func endSession(completed: Bool) {
        guard var session = activeSession else { return }
        session.endedAt       = Date()
        session.wasCompleted  = completed
        session.iterationCount = iterationCount

        timer.stop()
        activeSession      = nil
        iterationCount     = 0
        showOverflowBanner = false

        todaySessions.append(session)
        updateStreak()
        store.save(sessions: todaySessions, streak: streak)
    }

    func skipSession() {
        if activeSession != nil {
            endSession(completed: false)
        }
        // Advance to next sensible mode
        let next: SessionMode = currentMode == .deep ? .rest : .deep
        setMode(next)
    }

    func resetSession() {
        timer.reset()
        activeSession      = nil
        iterationCount     = 0
        showOverflowBanner = false
        timer.load(seconds: currentMode.duration)
    }

    // MARK: - Overflow actions (gentle end)

    func extendSession() {
        showOverflowBanner = false
        timer.extend(by: 5 * 60)
    }

    func finishFromOverflow() {
        endSession(completed: true)
        showOverflowBanner = false
    }

    // MARK: - Iteration counter

    func addIteration() {
        iterationCount += 1
    }

    // MARK: - Computed stats

    var breakDebt: Int {
        dayRecord.workSessionsSinceBreak
    }

    var breakDebtLevel: BreakDebtLevel {
        switch breakDebt {
        case 0...2: return .ok
        case 3...4: return .warning
        default:    return .critical
        }
    }

    var flowScore: Int { dayRecord.flowScore }

    var focusTimeFormatted: String {
        formatDuration(dayRecord.totalFocusTime)
    }

    var aiWaitTimeFormatted: String {
        formatDuration(dayRecord.totalAIWaitTime)
    }

    var completionRate: Int { dayRecord.completionRate }

    var menubarLabel: String {
        "\(timer.displayString)"
    }

    // Last 10 sessions for the dot history strip
    var recentHistory: [Session] {
        Array(todaySessions.suffix(10))
    }

    // MARK: - Private helpers

    private var dayRecord: DayRecord {
        DayRecord(date: Date(), sessions: todaySessions, streak: streak)
    }

    private func bindTimerEnd() {
        timer.onNaturalEnd
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleNaturalEnd()
            }
            .store(in: &cancellables)
    }

    private func handleNaturalEnd() {
        // For rest mode, auto-complete without prompt
        if currentMode == .rest {
            endSession(completed: true)
            setMode(.deep)
            return
        }
        // For work modes: show gentle overflow banner
        showOverflowBanner = true
        NSSound.beep()   // subtle system beep — v2 will replace with custom sound
    }

    private func updateStreak() {
        let deepCompleted = todaySessions.filter {
            $0.mode == .deep && $0.wasCompleted
        }.count
        streak = deepCompleted  // streak = completed deep sessions today
        // v2: carry streak across days using persistent date tracking
    }

    private func loadToday() {
        let record   = store.loadToday()
        todaySessions = record.sessions
        streak        = record.streak
    }

    private func formatDuration(_ ti: TimeInterval) -> String {
        let total = Int(ti)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Break debt level
enum BreakDebtLevel {
    case ok, warning, critical

    var color: Color {
        switch self {
        case .ok:       return Color(hex: "#1D9E75")
        case .warning:  return Color(hex: "#EF9F27")
        case .critical: return Color(hex: "#E24B4A")
        }
    }

    var label: String {
        switch self {
        case .ok:       return "Al día"
        case .warning:  return "Toma un break pronto"
        case .critical: return "Break necesario"
        }
    }
}
