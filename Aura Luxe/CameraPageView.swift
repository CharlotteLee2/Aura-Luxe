import SwiftUI

struct CameraPageView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraView()
                .ignoresSafeArea()

            VStack {
                Text("Camera Page")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                Spacer()
            }
        }
    }
}
