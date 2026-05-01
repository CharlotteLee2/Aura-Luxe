import SwiftUI

struct HomeView: View {
    @State private var cachedPopularProducts: [SephoraPopularProduct] = []
    @State private var didInitialLoad = false
    @State private var recommendedProducts: [RecommendedProduct] = []
    @State private var likedProductNames: Set<String> = []
    @State private var isLoadingRecommended = false

    private static var hasRefreshedThisSession = false
    private let popularService = SephoraPopularProductsService()
    private let recommendedService = RecommendedProductsService()
    private let likedService = LikedProductsService()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.97, blue: 0.96),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.95, green: 0.99, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topRow
                        trendingCard
                        popularCirclesSection
                        recommendedSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
        }
        .task {
            if didInitialLoad { return }
            didInitialLoad = true
            await loadCachedPopularProducts()
            await loadRecommendedAndLiked()

            if !Self.hasRefreshedThisSession {
                Self.hasRefreshedThisSession = true
                do {
                    try await popularService.refreshViaBackend(timeoutSeconds: 5)
                    await loadCachedPopularProducts()
                } catch {
                    // Keep old cache if refresh fails.
                }
            }
        }
    }

    private var topRow: some View {
        HStack {
            Button {
                // TODO: open logo landing
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("AL")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    )
            }

            Spacer()

            Text("Home")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

            Spacer()

            Button {
                // TODO: open profile
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    )
            }
        }
    }

    private var trendingCard: some View {
        let hero = cachedPopularProducts.first(where: { $0.slot == 0 })

        return Button {
            // TODO: open trending product
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let hero, let url = URL(string: hero.imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color(red: 0.78, green: 0.88, blue: 0.86)
                        }
                    } else {
                        Color(red: 0.78, green: 0.88, blue: 0.86)
                    }
                }
                .frame(height: 186)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 22))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayProductName(hero?.name) ?? "Trending product")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(hero?.subtitle ?? "Trending now on Sephora")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(14)
            }
        }
    }

    private var popularCirclesSection: some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { i in
                let slot = i + 1
                let product = cachedPopularProducts.first(where: { $0.slot == slot })

                Button {
                    // TODO: open popular product
                } label: {
                    VStack(spacing: 8) {
                        Group {
                            if let product, let url = URL(string: product.imageURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color(red: 0.81, green: 0.91, blue: 0.89)
                                }
                            } else {
                                Color(red: 0.81, green: 0.91, blue: 0.89)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.95), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

                        Text(displayProductName(product?.name) ?? "Popular product")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.18, green: 0.23, blue: 0.23))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(width: 94)
                            .minimumScaleFactor(0.9)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func loadCachedPopularProducts() async {
        do {
            cachedPopularProducts = try await popularService.fetchCachedPopularProducts()
        } catch {
            // If read fails, keep existing state (could be empty).
        }
    }

    private func loadRecommendedAndLiked() async {
        isLoadingRecommended = true
        defer { isLoadingRecommended = false }
        async let products = try? recommendedService.fetchRecommendedProducts()
        async let liked    = try? likedService.fetchLikedProductNames()
        let (p, l) = await (products, liked)
        recommendedProducts = p ?? []
        likedProductNames   = l ?? []
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Products For You")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.15, green: 0.20, blue: 0.20))

            if isLoadingRecommended {
                ForEach(0..<6, id: \.self) { _ in shimmerCard }
            } else if recommendedProducts.isEmpty {
                Text("No recommendations yet. Complete your skin quiz to get started.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .padding(.top, 8)
            } else {
                ForEach(recommendedProducts) { product in
                    recommendedProductCard(product)
                }
            }
        }
    }

    private var shimmerCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                .frame(width: 86, height: 96)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.white.opacity(0.9))
                )
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.72, green: 0.82, blue: 0.82))
                    .frame(width: 86, height: 18)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                    .frame(width: 140, height: 14)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    private func recommendedProductCard(_ product: RecommendedProduct) -> some View {
        let isLiked = likedProductNames.contains(product.name)
        return HStack(spacing: 14) {
            Group {
                if let urlString = product.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(red: 0.82, green: 0.90, blue: 0.90)
                    }
                } else {
                    Color(red: 0.82, green: 0.90, blue: 0.90)
                        .overlay(
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.white.opacity(0.9))
                        )
                }
            }
            .frame(width: 86, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(displayProductName(product.name) ?? product.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.22, blue: 0.22))
                    .lineLimit(2)
                Text(product.skinTypes.joined(separator: ", ").capitalized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            }

            Spacer()

            Button {
                Task { await toggleLike(for: product) }
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isLiked
                            ? Color(red: 0.34, green: 0.53, blue: 0.52)
                            : Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.4)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .scaleEffect(isLiked ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isLiked)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    private func toggleLike(for product: RecommendedProduct) async {
        let currentlyLiked = likedProductNames.contains(product.name)
        if currentlyLiked { likedProductNames.remove(product.name) }
        else { likedProductNames.insert(product.name) }
        do {
            _ = try await likedService.toggleLike(productName: product.name, currentlyLiked: currentlyLiked)
        } catch {
            if currentlyLiked { likedProductNames.insert(product.name) }
            else { likedProductNames.remove(product.name) }
        }
    }

    private func displayProductName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let compact = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanupRules: [(String, String)] = [
            ("Synchronized Multi-Recovery Complex", ""),
            ("with Hyaluronic Acid", ""),
            ("Night Repair", "Night Repair"),
            ("Treatment Lotion with Hyaluronic Acid", "Treatment Lotion"),
            ("Hydrating and Pore-Refining Toner", "Pore-Refining Toner"),
            ("Invisible Daily Sunscreen SPF 50", "Daily Sunscreen SPF 50"),
            ("Face Serum", "Serum"),
            ("Moisturizer for", "Moisturizer"),
        ]

        var value = compact
        for (target, replacement) in cleanupRules {
            value = value.replacingOccurrences(of: target, with: replacement, options: .caseInsensitive)
        }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if value.count > 46 {
            let words = value.split(separator: " ").prefix(6)
            value = words.joined(separator: " ")
        }

        return value
    }
}
