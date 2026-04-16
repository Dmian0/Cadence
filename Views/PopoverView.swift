import SwiftUI

struct PopoverView: View {
    @ObservedObject var vm: SessionViewModel

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack {
                Circle()
                    .fill(vm.currentMode.color)
                    .frame(width: 8, height: 8)
                Text("Cadence")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                // Streak badge
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 11))
                    Text("\(vm.streak)")
                        .font(.system(size: 11, weight: .medium))
                    Text(NSLocalizedString("streak", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(20)
                .overlay(
                    Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().opacity(0.5)

            // ── Mode tabs ────────────────────────────────────────
            ModeTabsView(vm: vm)

            // ── Undo pill ────────────────────────────────────────
            if vm.showUndoModeChange {
                UndoPillView { vm.undoModeChange() }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }

            // ── Timer ────────────────────────────────────────────
            VStack(spacing: 12) {
                TimerRingView(
                    progress: vm.timer.progress,
                    mode: vm.currentMode,
                    timeString: vm.timer.displayString,
                    isOverflow: vm.timer.isOverflow
                )

                // Overflow banner (gentle, no alarm)
                if vm.showOverflowBanner {
                    OverflowBannerView(vm: vm)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Controls
                    ControlsView(vm: vm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .animation(.spring(response: 0.35), value: vm.showOverflowBanner)

            // ── AI Pause shortcut (only during non-AI sessions) ──
            if vm.currentMode != .aiWait && vm.activeSession != nil {
                Button {
                    vm.setMode(.aiWait)
                    vm.startSession()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#1D9E75"))
                            .frame(width: 6, height: 6)
                        Text(NSLocalizedString("ai_pause_button", comment: ""))
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#0F6E56"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#1D9E75").opacity(0.5), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            // ── Session history dots ─────────────────────────────
            HistoryDotsView(sessions: vm.recentHistory, currentMode: vm.currentMode, totalCount: vm.todaySessions.count)

            Divider().opacity(0.5)

            // ── Stats row ────────────────────────────────────────
            StatsRowView(vm: vm)
        }
        .frame(width: 280)
    }
}

// MARK: - Controls
private struct ControlsView: View {
    @ObservedObject var vm: SessionViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Reset
            CircleButton(symbol: "backward.end.fill", size: 36) {
                vm.resetSession()
            }

            // Play / Pause (primary)
            CircleButton(
                symbol: vm.timer.isRunning ? "pause.fill" : "play.fill",
                size: 44,
                isPrimary: true,
                accentColor: vm.currentMode.color
            ) {
                vm.togglePlayPause()
            }

            // Skip
            CircleButton(symbol: "forward.end.fill", size: 36) {
                vm.skipSession()
            }
        }

        // Iteration counter (only during active AI-related sessions)
        if vm.activeSession != nil && vm.currentMode != .rest {
            IterationCounterView(count: vm.iterationCount) {
                vm.addIteration()
            }
        }
    }
}

// MARK: - Overflow banner
private struct OverflowBannerView: View {
    @ObservedObject var vm: SessionViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("session_complete", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Button(NSLocalizedString("extend_five", comment: "")) {
                    vm.extendSession()
                }
                .buttonStyle(PillButtonStyle(color: vm.currentMode.color))

                Button(NSLocalizedString("finish", comment: "")) {
                    vm.finishFromOverflow()
                }
                .buttonStyle(PillButtonStyle(color: .primary.opacity(0.6)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(vm.currentMode.color.opacity(0.15))
        .cornerRadius(10)
    }
}

// MARK: - Iteration counter
private struct IterationCounterView: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                Text(count == 0
                     ? NSLocalizedString("count_iteration", comment: "")
                     : String(format: NSLocalizedString(count == 1 ? "iterations_one" : "iterations_other", comment: ""), count))
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History dots
private struct HistoryDotsView: View {
    let sessions: [Session]
    let currentMode: SessionMode
    let totalCount: Int

    private let totalSlots = 10

    var body: some View {
        let visibleSessions = Array(sessions.suffix(totalSlots - 1)) // leave 1 slot for current
        let filledCount = visibleSessions.count
        let emptyCount = max(0, totalSlots - filledCount - 1)

        HStack(spacing: 3) {
            // Past sessions (sliding window — latest N)
            ForEach(Array(visibleSessions.enumerated()), id: \.offset) { _, session in
                RoundedRectangle(cornerRadius: 3)
                    .fill(session.mode.color.opacity(session.wasCompleted ? 1 : 0.4))
                    .frame(width: 10, height: 10)
            }

            // Current session slot — pulsing
            RoundedRectangle(cornerRadius: 3)
                .fill(currentMode.color.opacity(0.5))
                .frame(width: 10, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(currentMode.color, lineWidth: 1.5)
                )

            // Empty slots
            ForEach(0..<emptyCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 10, height: 10)
            }

            Spacer()

            Text(String(format: NSLocalizedString("today_sessions", comment: ""), totalCount))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Stats row
struct StatsRowView: View {
    @ObservedObject var vm: SessionViewModel

    var body: some View {
        HStack(spacing: 0) {
            StatCell(value: vm.focusTimeFormatted,   label: NSLocalizedString("focus_today", comment: ""))
            Divider().frame(height: 30)
            StatCell(value: vm.aiWaitTimeFormatted,  label: NSLocalizedString("ai_wait_stat", comment: ""))
            Divider().frame(height: 30)
            StatCell(value: "\(vm.flowScore)",        label: NSLocalizedString("flow_score", comment: ""))
        }
        .padding(.vertical, 4)

        // Break debt indicator
        if vm.breakDebtLevel != .ok {
            HStack(spacing: 4) {
                Circle()
                    .fill(vm.breakDebtLevel.color)
                    .frame(width: 5, height: 5)
                Text(vm.breakDebtLevel.label)
                    .font(.system(size: 10))
                    .foregroundColor(vm.breakDebtLevel.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}

private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Reusable button styles
private struct CircleButton: View {
    let symbol: String
    let size: CGFloat
    var isPrimary: Bool = false
    var accentColor: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 17 : 13, weight: .semibold))
                .frame(width: size, height: size)
                .background(isPrimary ? accentColor : Color.clear)
                .foregroundColor(isPrimary ? .white : .primary)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        isPrimary ? Color.clear : Color.primary.opacity(0.15),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Undo pill
private struct UndoPillView: View {
    let onUndo: () -> Void

    var body: some View {
        Button(action: onUndo) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                Text(NSLocalizedString("mode_changed_undo", comment: ""))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.primary.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(20)
            .overlay(
                Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            .foregroundColor(color)
            .cornerRadius(20)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
    }
}
