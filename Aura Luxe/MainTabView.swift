import SwiftUI

struct MainTabView: View {
    private enum Tab: CaseIterable {
        case home
        case myProducts
        case camera
        case habitTracker
        case search

        var title: String {
            switch self {
            case .home: return "Home"
            case .myProducts: return "My Products"
            case .camera: return "Camera"
            case .habitTracker: return "Habit Tracker"
            case .search: return "Search"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .myProducts: return "shippingbox.fill"
            case .camera: return "camera.fill"
            case .habitTracker: return "checklist"
            case .search: return "magnifyingglass"
            }
        }
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeView()
            case .myProducts:
                MyProductsPageView()
            case .camera:
                CameraPageView()
            case .habitTracker:
                HabitTrackerPageView()
            case .search:
                SearchPageView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.title) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.95, blue: 0.93))
                        .frame(width: isSelected ? 46 : 32, height: isSelected ? 46 : 32)

                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 19 : 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.19, green: 0.34, blue: 0.33))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 48)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.33))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
