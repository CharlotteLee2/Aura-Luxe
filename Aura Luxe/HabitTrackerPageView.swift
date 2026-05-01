import SwiftUI

struct HabitTrackerPageView: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.99, blue: 0.97)
                .ignoresSafeArea()

            Text("Habit Tracker Page")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.18, green: 0.27, blue: 0.27))
        }
    }
}
