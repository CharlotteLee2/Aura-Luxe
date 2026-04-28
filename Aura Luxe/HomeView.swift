import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Text("Home")
                .font(.largeTitle)
                .fontWeight(.semibold)
        }
    }
}
