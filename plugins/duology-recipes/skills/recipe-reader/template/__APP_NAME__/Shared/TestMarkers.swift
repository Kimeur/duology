import SwiftUI

extension View {
    /// A machine-readable state for UI tests, such as "book=keeper|chapter=0|offset=1520|".
    /// Only with -uiTesting in a debug build: VoiceOver never meets the extra element.
    @ViewBuilder
    func testMarker(_ id: String, value: @autoclosure () -> String) -> some View {
        if LaunchOptions.isUITesting {
            overlay {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier(id)
                    .accessibilityValue(value())
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}

extension Color {
    /// A colour from hex RGB, as the library stores cover colours ("1F4E79").
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x808080
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
