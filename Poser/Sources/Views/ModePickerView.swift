import SwiftUI

struct ModePickerView: View {
    @Binding var selected: DrawingMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DrawingMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) { selected = mode }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selected == mode
                        ? Color.white.opacity(0.15)
                        : Color.clear)
                    .foregroundColor(selected == mode ? .white : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
