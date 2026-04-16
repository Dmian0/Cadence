import SwiftUI

struct TimerRingView: View {
    let progress: Double      // 0.0 → 1.0
    let mode: SessionMode
    let timeString: String
    let isOverflow: Bool

    private let ringSize: CGFloat   = 120
    private let lineWidth: CGFloat  = 5

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            // Fill — rotates from 12 o'clock
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOverflow ? mode.color.opacity(0.4) : mode.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: progress)

            // Overflow pulse ring
            if isOverflow {
                Circle()
                    .stroke(mode.color.opacity(0.25), lineWidth: 2)
                    .scaleEffect(isOverflow ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isOverflow
                    )
            }

            // Center content
            VStack(spacing: 2) {
                if isOverflow {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#1D9E75"))
                }

                Text(timeString)
                    .font(.system(size: 26, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)

                if isOverflow {
                    Text(NSLocalizedString("completed_label", comment: ""))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#1D9E75"))
                }
            }
        }
        .frame(width: ringSize, height: ringSize)
    }
}
