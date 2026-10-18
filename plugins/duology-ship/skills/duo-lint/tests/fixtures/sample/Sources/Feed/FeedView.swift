import SwiftUI
import UIKit

struct FeedView: View {
    var body: some View {
        Image(systemName: "photo")
            .resizable()
            .frame(height: UIScreen.main.bounds.width * 0.6)
    }
}
