// duo-lint sample app: the "Read the output" example in SKILL.md is real output on Sources/.
import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        let columns = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 1
        Text("\(columns) columns")
    }
}
