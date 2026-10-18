// duo-lint test fixture: code Apple tells you to remove before shipping on iPhone Duo.
// Each line marked "expect:" must produce exactly the rules listed after it.
// Unmarked lines must produce nothing. This file typechecks against the iOS 27.1 SDK
// (with deprecation warnings, which are the point).
import SwiftUI
import UIKit

final class LegacyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let width = UIScreen.main.bounds.width // expect: DUO001
        let scale = UIScreen.main.scale // expect: DUO001
        let count = UIScreen.screens.count // expect: DUO001
        print(width, scale, count)

        if UIDevice.current.orientation.isLandscape { // expect: DUO002
            print("landscape")
        }
        if UIApplication.shared.statusBarOrientation == .portrait { // expect: DUO003
            print("portrait")
        }
        if view.window?.windowScene?.interfaceOrientation == .landscapeLeft { // expect: DUO003
            print("left")
        }
        if interfaceOrientation.isPortrait { // expect: DUO003
            print("portrait")
        }
        if let geometry = view.window?.windowScene?.effectiveGeometry,
           geometry.interfaceOrientation.isLandscape { // expect: DUO002
            print("landscape")
        }
        if UIDevice.current.userInterfaceIdiom == .pad { // expect: DUO004
            print("pad layout")
        }
        // Two columns on iPad.
        if traitCollection.horizontalSizeClass == .regular { // expect: DUO005
            print("two columns")
        }
        if view.bounds.height == 844 { // expect: DUO006
            print("iPhone 14")
        }
        if [568.0, 667.0, 736.0].contains(view.bounds.height) { // expect: DUO006
            print("small phone")
        }
        switch view.bounds.height {
        case 568, 667: // expect: DUO006
            print("small")
        default:
            break
        }
        let panel = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) // expect: DUO006
        panel.widthAnchor.constraint(equalToConstant: 390).isActive = true // expect: DUO007
        view.addSubview(panel)

        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, // expect: DUO002
            object: nil, queue: .main) { _ in }

        let window = UIWindow(frame: UIScreen.main.bounds) // expect: DUO001
        print(window)

        let message = "Width \(UIScreen.main.bounds.width)" // expect: DUO001
        print(message)

        // duo-lint:disable-next-line DUO001 -- legacy analytics, not layout
        let legacyScale = UIScreen.main.scale
        let nativeScale = UIScreen.main.nativeScale // duo-lint:disable-line
        // duo-lint:disable-next-line DUO004
        let wrongRule = UIScreen.main.nativeBounds // expect: DUO001
        print(legacyScale, nativeScale, wrongRule)
    }
}

struct LegacyScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool { sizeClass == .regular } // expect: DUO005
    private var columns: Int { UIDevice.current.userInterfaceIdiom == .phone ? 1 : 2 } // expect: DUO004

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 1024 { // expect: DUO009
                Text("Big iPad")
            } else if proxy.size.width == 393 { // expect: DUO009
                Text("iPhone 15")
            }
        }
        .frame(width: 390) // expect: DUO007
        .frame(minWidth: 400, maxWidth: .infinity) // expect: DUO007
        .frame(
            width: 500, // expect: DUO007
            height: 300
        )
    }
}

@MainActor
final class SceneReader {
    func read(_ windowScene: UIWindowScene, controller: UIViewController) {
        let geometry = windowScene.effectiveGeometry
        let shape = geometry.interfaceOrientation // expect: DUO002
        let old = windowScene.interfaceOrientation // expect: DUO003
        let legacy = controller.interfaceOrientation // expect: DUO003
        let first = UIApplication.shared.connectedScenes.first
        let cast = (first as? UIWindowScene)?.interfaceOrientation // expect: DUO003
        print(shape, old, legacy, cast as Any)
    }

    func screens(for scene: UIWindowScene?) {
        let screen: UIScreen = .main // expect: DUO001
        let fallback = scene?.screen ?? .main // expect: DUO001
        print(screen, fallback)
    }

    var fallbackScreen: UIScreen { .main } // expect: DUO001

    func defaultScreen() -> UIScreen {
        .main // expect: DUO001
    }

    func columns() -> Int {
        let idiom = UIDevice.current.userInterfaceIdiom
        if idiom == .pad { return 2 } // expect: DUO004
        if case .phone = UIDevice.current.userInterfaceIdiom { return 1 } // expect: DUO004
        return 0
    }
}
