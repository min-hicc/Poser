import SwiftUI

struct ModePickerView: View {
    @Binding var selected: Set<DrawingMode>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DrawingMode.allCases) { mode in
                let isOn = selected.contains(mode)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if isOn { selected.remove(mode) }
                        else    { selected.insert(mode) }
                    }
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
                    .background(isOn ? Color.white.opacity(0.15) : Color.clear)
                    .foregroundColor(isOn ? .white : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
