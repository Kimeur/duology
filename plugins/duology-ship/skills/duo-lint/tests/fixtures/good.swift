// duo-lint test fixture: adaptive code that must produce no findings.
// It also holds look-alikes that a naive text search would flag:
// UIScreen.main.bounds, UIDevice.current.orientation and == 844 inside comments.
/* A nested /* block */ comment: userInterfaceIdiom == .pad, .frame(width: 390) */
import SwiftUI
import UIKit

struct AdaptiveScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayScale) private var displayScale

    private let note = "Never use UIScreen.main or userInterfaceIdiom == .pad"
    private let raw = #"Raw "UIScreen.main.bounds" text with \(not interpolated)"#
    private let multi = """
        if bounds.height == 844 { }
        .frame(width: 390)
        """

    var body: some View {
        let layout = sizeClass == .regular
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 12))
        GeometryReader { proxy in
            layout {
                Text("\(Int(proxy.size.width)) x \(Int(proxy.size.height)) at \(displayScale)x")
                Text(proxy.size.width > proxy.size.height ? "Wide" : "Tall")
                Text(note + raw + multi)
            }
            .frame(maxWidth: 600)
            .frame(width: 44, height: 44)
        }
        .frame(maxWidth: .infinity)
    }
}

final class AdaptiveViewController: UIViewController {
    private var tiles: [UIView] = []

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let isWide = view.bounds.width > view.bounds.height
        let scale = traitCollection.displayScale
        let screen = view.window?.windowScene?.screen
        let imageSize = CGSize(width: 2048, height: 1536)
        if imageSize.width > 1024 {
            print("downscale the image")
        }
        if tiles.count > 1024 {
            print("too many tiles")
        }
        for _ in 0..<390 { }
        if traitCollection.userInterfaceIdiom == .mac {
            print("Mac Catalyst")
        }
        print(isWide, scale, String(describing: screen))
    }

    func makeWindow(for scene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        let label = UILabel()
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 600).isActive = true
        window.addSubview(label)
        return window
    }
}
