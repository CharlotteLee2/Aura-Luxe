import SwiftUI

struct MyProductsPageView: View {
    @State private var likedProducts: [RecommendedProduct] = []
    @State private var likedProductNames: Set<String> = []
    @State private var isLoading = true
    @State private var didInitialLoad = false

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
                        productsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await loadLikedProducts()
        }
    }

    // MARK: - Subviews

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

            Text("My Products")
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

    @ViewBuilder
    private var productsSection: some View {
        if isLoading {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in shimmerCard }
            }
        } else if likedProducts.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(likedProducts.count) saved product\(likedProducts.count == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))

                ForEach(likedProducts) { product in
                    likedProductCard(product)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 48)

            Image(systemName: "heart")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.45))

            Text("No saved products yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

            Text("Tap the heart on any recommended product to save it here.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
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

    private func likedProductCard(_ product: RecommendedProduct) -> some View {
        HStack(spacing: 14) {
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
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.22, blue: 0.22))
                    .lineLimit(2)
                Text(product.skinTypes.joined(separator: ", ").capitalized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            }

            Spacer()

            Button {
                Task { await unlike(product: product) }
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    // MARK: - Data

    private func loadLikedProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await likedService.fetchLikedProducts()
            likedProducts = products
            likedProductNames = Set(products.map(\.name))
        } catch {
            likedProducts = []
        }
    }

    private func unlike(product: RecommendedProduct) async {
        likedProductNames.remove(product.name)
        withAnimation {
            likedProducts.removeAll { $0.name == product.name }
        }
        do {
            try await likedService.unlike(productName: product.name)
        } catch {
            likedProducts.insert(product, at: 0)
            likedProductNames.insert(product.name)
        }
    }
}
