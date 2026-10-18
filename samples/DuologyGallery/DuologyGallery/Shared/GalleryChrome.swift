import SwiftUI

// MARK: - Launch arguments

/// Launch arguments land in UserDefaults' argument domain, so
/// `-pattern listDetail` reads back as the string "listDetail" for the key "pattern".
enum LaunchOptions {
    /// `-pattern <name>` opens that pattern straight away. Names match `Pattern` cases.
    static var pattern: Pattern? {
        UserDefaults.standard.string(forKey: "pattern").flatMap(Pattern.init(rawValue:))
    }

    /// `-select <id>` preselects an item in screens that have a selection
    /// (list-detail, dual view). Used for screenshots.
    static var selection: Int? {
        UserDefaults.standard.object(forKey: "select") == nil ? nil : UserDefaults.standard.integer(forKey: "select")
    }

    /// `-show map` starts the dual view on its map when only one view fits.
    static var show: String? {
        UserDefaults.standard.string(forKey: "show")
    }
}

// MARK: - Closing a pattern

/// Takes the person back to the gallery's home screen.
nonisolated struct ClosePatternAction: Sendable {
    var action: @MainActor @Sendable () -> Void = {}

    @MainActor func callAsFunction() { action() }
}

nonisolated private struct ClosePatternKey: EnvironmentKey {
    static let defaultValue = ClosePatternAction()
}

extension EnvironmentValues {
    nonisolated var closePattern: ClosePatternAction {
        get { self[ClosePatternKey.self] }
        set { self[ClosePatternKey.self] = newValue }
    }
}

/// The button that leaves a pattern. It sits in the system toolbar, so on
/// iPhone Duo it moves to the top of a vertical bar like any Close button.
struct CloseGalleryButton: View {
    @Environment(\.closePattern) private var close

    var body: some View {
        Button("Gallery", systemImage: "xmark") { close() }
            .accessibilityLabel("Back to the gallery")
    }
}

extension View {
    /// Adds the Close button to this screen's navigation bar.
    func galleryCloseButton() -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CloseGalleryButton()
            }
        }
    }
}

// MARK: - Small shared views

/// A round avatar with initials, for people in the sample data.
struct InitialsAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

extension Color {
    /// A colour from a 0xRRGGBB value.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}
