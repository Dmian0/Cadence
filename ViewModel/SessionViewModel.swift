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
    @Published var showUndoModeChange: Bool = false

    // MARK: - Day data
    @Published private(set) var todaySessions: [Session] = []
    @Published private(set) var streak: Int = 0

    // MARK: - Sub-objects
    let timer = TimerEngine()

    // MARK: - Private
    private let store = DayStore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Undo state
    private var previousMode: SessionMode?
    private var previousSession: Session?
    private var previousSecondsRemaining: Int = 0
    private var previousIterationCount: Int = 0
    private var undoTimer: AnyCancellable?

    // MARK: - Init
    init() {
        loadToday()
        bindTimerEnd()

        // Forward TimerEngine changes so SwiftUI views observing
        // SessionViewModel also re-render on every timer tick.
        timer.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Mode

    func setMode(_ mode: SessionMode) {
        // Save state for undo if there's an active session
        if activeSession != nil {
            previousMode = currentMode
            previousSession = activeSession
            previousSecondsRemaining = timer.secondsRemaining
            previousIterationCount = iterationCount
            endSession(completed: false)
            triggerUndo()
        }
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

    // MARK: - Undo mode change

    func undoModeChange() {
        guard let prevMode = previousMode, let prevSession = previousSession else { return }
        showUndoModeChange = false
        undoTimer?.cancel()

        // Remove the incomplete session that was saved when mode changed
        if let lastIdx = todaySessions.lastIndex(where: { $0.id == prevSession.id }) {
            todaySessions.remove(at: lastIdx)
        } else if !todaySessions.isEmpty {
            // The ended session was appended — remove the last one
            todaySessions.removeLast()
        }

        // Restore previous state
        currentMode = prevMode
        activeSession = prevSession
        iterationCount = previousIterationCount
        timer.load(seconds: previousSecondsRemaining)
        timer.start()
        showOverflowBanner = false

        // Clear undo state
        previousMode = nil
        previousSession = nil

        store.save(sessions: todaySessions, streak: streak)
    }

    private func triggerUndo() {
        showUndoModeChange = true
        undoTimer?.cancel()
        undoTimer = Just(())
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.showUndoModeChange = false
                self?.previousMode = nil
                self?.previousSession = nil
            }
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

    /// Reset all state — used by dev reset in context menu
    func reloadData() {
        timer.stop()
        activeSession = nil
        iterationCount = 0
        showOverflowBanner = false
        showUndoModeChange = false
        currentMode = .deep
        timer.load(seconds: SessionMode.deep.duration)
        loadToday()
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
        // Timer reached zero → session counts as completed regardless of
        // whether the user extends or switches mode afterwards.
        activeSession?.wasCompleted = true
        // Show gentle overflow banner for +5 min / Terminar options
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
        case .ok:       return NSLocalizedString("on_track", comment: "")
        case .warning:  return NSLocalizedString("take_break_soon", comment: "")
        case .critical: return NSLocalizedString("break_needed", comment: "")
        }
    }
}
