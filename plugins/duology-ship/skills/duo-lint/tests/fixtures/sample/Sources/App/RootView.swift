// duo-lint sample app. The example output in SKILL.md and the READMEs is real output on Sources/; a test checks it.
import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        let columns = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        Text("\(columns) columns")
    }
}
