import SwiftUI

struct ModeTabsView: View {
    @ObservedObject var vm: SessionViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SessionMode.allCases, id: \.self) { mode in
                ModeTab(
                    mode: mode,
                    isActive: vm.currentMode == mode,
                    onTap: { vm.setMode(mode) }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }
}

private struct ModeTab: View {
    let mode: SessionMode
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(mode.emoji)
                    .font(.system(size: 14))
                Text(mode.label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isActive ? mode.lightBackground : Color.clear)
            .foregroundColor(isActive ? mode.color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isActive ? mode.color.opacity(0.5) : Color.primary.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }
}
