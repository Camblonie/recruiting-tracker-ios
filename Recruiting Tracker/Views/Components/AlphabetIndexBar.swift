import SwiftUI

/// Vertical A–Z sidebar index for quick navigation.
/// - Renders A–Z vertically and invokes `onTap` for enabled letters.
/// - Keep styling lightweight to blend with the app's theme.
struct AlphabetIndexBar: View {
    /// Letters to display, e.g. ["A", "B", ..., "Z"]
    let letters: [String]
    /// Which letters have at least one anchor in the current list
    let enabled: Set<String>
    /// Tap handler
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    if enabled.contains(letter) {
                        onTap(letter)
                    }
                } label: {
                    Text(letter)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(enabled.contains(letter) ? .white : .white.opacity(0.38))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!enabled.contains(letter))
            }
        }
        .padding(6)
        .background(Color.slate.opacity(0.7))
        .clipShape(Capsule())
        .shadow(color: Color.slate.opacity(0.15), radius: 2, x: 0, y: 1)
        .padding(.trailing, 2)
        .accessibilityLabel("Alphabet index")
    }
}

#Preview {
    AlphabetIndexBar(
        letters: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) },
        enabled: ["A", "B", "C", "M"],
        onTap: { _ in }
    )
    .padding()
    .background(Color.skyBlue.opacity(0.2))
}
