import Foundation
import Combine

final class TimerEngine: ObservableObject {

    // MARK: - Published state
    @Published private(set) var secondsRemaining: Int = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isOverflow: Bool = false   // timer hit zero, gently glowing

    // MARK: - Private
    private var totalSeconds: Int = 0
    private var cancellable: AnyCancellable?

    // Fires when timer naturally reaches zero (for gentle overflow UX)
    let onNaturalEnd = PassthroughSubject<Void, Never>()

    // MARK: - Public interface

    func load(seconds: Int) {
        stop()
        totalSeconds     = seconds
        secondsRemaining = seconds
        isOverflow       = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        isRunning = false
        cancellable?.cancel()
        cancellable = nil
    }

    func stop() {
        pause()
        secondsRemaining = totalSeconds
        isOverflow = false
    }

    func reset() {
        stop()
    }

    /// Add seconds to current session (gentle overflow "+5 min")
    func extend(by seconds: Int) {
        isOverflow = false
        secondsRemaining += seconds
        totalSeconds = secondsRemaining   // reset so progress ring starts full
        if !isRunning { start() }
    }

    // MARK: - Progress (0.0 → 1.0)
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    // MARK: - Formatted display
    var displayString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Private
    private func tick() {
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else if !isOverflow {
            isOverflow = true
            pause()
            onNaturalEnd.send()
        }
    }
}
