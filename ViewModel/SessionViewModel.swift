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
    @Published private(set) var overflowContext: OverflowContext = .normal

    // MARK: - Sub-session state
    @Published private(set) var suspendedParentSession: Session? = nil
    @Published private(set) var suspendedParentSeconds: Int = 0
    @Published var showSubSessionChoice: Bool = false
    @Published private(set) var pendingMode: SessionMode? = nil

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
        guard mode != currentMode else { return }

        if activeSession != nil {
            // Active session — show choice banner, pause timer
            pendingMode = mode
            showSubSessionChoice = true
            timer.pause()
        } else {
            // No active session — clean switch
            currentMode = mode
            timer.load(seconds: mode.duration)
            iterationCount = 0
            showOverflowBanner = false
        }
    }

    // MARK: - Sub-session choice (from banner)

    func confirmAsSubSession() {
        guard let mode = pendingMode else { return }
        showSubSessionChoice = false
        pendingMode = nil

        if suspendedParentSession != nil {
            // Already in a sub-session — complete current, start sibling
            completeCurrentSubSession()
            startSubSession(mode: mode)
        } else {
            // First sub-session — suspend parent
            suspendSession()
            startSubSession(mode: mode)
        }
    }

    func confirmAsIndependent() {
        guard let mode = pendingMode else { return }
        showSubSessionChoice = false
        pendingMode = nil

        // Close current session as completed (user chose to end it)
        endSession(completed: true)

        // Clear any suspended parent
        suspendedParentSession = nil
        suspendedParentSeconds = 0

        // Start fresh independent session setup
        currentMode = mode
        timer.load(seconds: mode.duration)
        iterationCount = 0
        showOverflowBanner = false
    }

    func cancelModeChange() {
        showSubSessionChoice = false
        pendingMode = nil
        if activeSession != nil { timer.start() }
    }

    // MARK: - Quick-action transitions

    func activateAIWait() {
        suspendSession()
        startSubSession(mode: .aiWait)
    }

    func activateReview() {
        completeCurrentSubSession()
        startSubSession(mode: .review)
    }

    func returnToDeepWork() {
        completeCurrentSubSession()
        resumeParentSession()
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
        session.endedAt        = Date()
        session.wasCompleted   = completed
        session.iterationCount = iterationCount

        timer.stop()
        activeSession      = nil
        iterationCount     = 0
        showOverflowBanner = false
        showSubSessionChoice = false

        if var parent = suspendedParentSession {
            // Ending during a sub-session — terminate parent too
            parent.subSessions.append(session)
            parent.endedAt = Date()
            parent.wasCompleted = completed
            todaySessions.append(parent)
            suspendedParentSession = nil
            suspendedParentSeconds = 0
        } else {
            todaySessions.append(session)
        }

        // Reset timer to mode's original duration
        timer.load(seconds: currentMode.duration)

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
    }

    /// Overflow action: from Review sub-session, return to parent
    func reviewOverflowReturnToParent() {
        showOverflowBanner = false
        completeCurrentSubSession()
        resumeParentSession()
    }

    /// Overflow action: from AI Wait sub-session, transition to Review
    func aiWaitOverflowStartReview() {
        showOverflowBanner = false
        completeCurrentSubSession()
        startSubSession(mode: .review)
    }

    /// Overflow action: finish Review sub-session (end both sub + parent)
    func finishReviewFromOverflow() {
        endSession(completed: true)
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
        showSubSessionChoice = false
        pendingMode = nil
        suspendedParentSession = nil
        suspendedParentSeconds = 0
        currentMode = .deep
        timer.load(seconds: SessionMode.deep.duration)
        loadToday()
    }

    // Last 10 sessions for the dot history strip
    var recentHistory: [Session] {
        Array(todaySessions.suffix(10))
    }

    // MARK: - Sub-session helpers (private)

    private func suspendSession() {
        suspendedParentSession = activeSession
        suspendedParentSeconds = timer.secondsRemaining
        timer.stop()
        activeSession = nil
    }

    private func startSubSession(mode: SessionMode) {
        let parentId = suspendedParentSession?.id
        currentMode = mode
        let session = Session(mode: mode, parentId: parentId)
        activeSession = session
        iterationCount = 0
        showOverflowBanner = false
        timer.load(seconds: mode.duration)
        timer.start()
    }

    private func completeCurrentSubSession() {
        guard var session = activeSession else { return }
        session.endedAt = Date()
        session.wasCompleted = true
        session.iterationCount = iterationCount
        timer.stop()

        if suspendedParentSession != nil {
            suspendedParentSession!.subSessions.append(session)
        }

        activeSession = nil
        iterationCount = 0
        showOverflowBanner = false
    }

    private func resumeParentSession() {
        guard let parent = suspendedParentSession else { return }
        currentMode = parent.mode
        activeSession = parent
        iterationCount = parent.iterationCount
        timer.load(seconds: suspendedParentSeconds)
        timer.start()

        suspendedParentSession = nil
        suspendedParentSeconds = 0
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

        // Timer reached zero → session counts as completed
        activeSession?.wasCompleted = true

        // Determine overflow context based on sub-session state
        if activeSession?.isSubSession == true, suspendedParentSession != nil {
            if currentMode == .aiWait {
                overflowContext = .aiWaitSub
            } else if currentMode == .review {
                overflowContext = .reviewSub
            } else {
                overflowContext = .normal
            }
        } else {
            overflowContext = .normal
        }

        showOverflowBanner = true
        NSSound.beep()
    }

    private func updateStreak() {
        let deepCompleted = todaySessions.filter {
            $0.mode == .deep && $0.wasCompleted
        }.count
        streak = deepCompleted
    }

    private func loadToday() {
        let record    = store.loadToday()
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

// MARK: - Overflow context
enum OverflowContext {
    case normal       // independent session: "+5 min" / "Terminar"
    case aiWaitSub    // AI Wait sub-session: "+5 min" / "Llegó la respuesta — revisar"
    case reviewSub    // Review sub-session: "+5 min" / "Terminar review" / "Volver a Deep Work"
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
