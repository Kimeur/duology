import SwiftUI

struct Controls: View {
    var body: some View {
        HStack {
            Image(systemName: "play.fill")
            Image(systemName: "forward.fill")
        }
        .frame(width: 390)
    }
}
