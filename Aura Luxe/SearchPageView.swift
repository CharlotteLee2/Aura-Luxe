import SwiftUI

struct SearchPageView: View {
    @State private var searchText = ""
    @FocusState private var fieldFocused: Bool
    @State private var searchResults: [RecommendedProduct] = []
    @State private var likedProductNames: Set<String> = []
    @State private var boardedProductNames: Set<String> = []
    @State private var isSearching = false
    @State private var didInitialLoad = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var productForSaveSheet: RecommendedProduct? = nil

    private let searchService = ProductSearchService()
    private let likedService = LikedProductsService()
    private let boardsService = BoardsService()
    private let categories = ["Cleanser", "Moisturizer", "Toner", "Serum"]

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

                        if fieldFocused && searchText.isEmpty {
                            categorySection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        contentArea
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: fieldFocused)
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await loadLikedProductNames()
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                searchResults = []
                isSearching = false
                return
            }
            isSearching = true
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await performSearch(query: trimmed)
            }
        }
        .sheet(item: $productForSaveSheet, onDismiss: {
            Task { boardedProductNames = (try? await boardsService.fetchBoardedProductNames()) ?? [] }
        }) { product in
            SaveToBoardSheet(productName: product.name)
        }
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(spacing: 10) {
            Button {} label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("AL")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    )
            }

            searchPill

            Button {} label: {
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

    private var searchPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))

            TextField("Search products...", text: $searchText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    fieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(
                            fieldFocused
                                ? Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.5)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Category dropdown

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Browse by category")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                VStack(spacing: 0) {
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                    Button {
                        searchText = category
                        fieldFocused = false
                    } label: {
                        HStack {
                            Text(category)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if !fieldFocused && searchText.isEmpty {
            emptyState
        } else if isSearching {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in shimmerCard }
            }
        } else if !searchText.isEmpty && searchResults.isEmpty {
            noResultsState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !searchResults.isEmpty {
                    Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s") for \"\(searchText)\"")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
                ForEach(searchResults) { product in
                    productCard(product)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)

            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.12))
                .frame(width: 88, height: 88)
                .overlay(
                    Text("AL")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                )

            Text("Discover skincare")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

            Text("Search by product name or browse a category")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 40)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.4))

            Text("No products found")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

            Text("Try a different name or browse a category")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 40)
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

    private func productCard(_ product: RecommendedProduct) -> some View {
        let isLiked = likedProductNames.contains(product.name)
        let isBoarded = boardedProductNames.contains(product.name)
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
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.22, blue: 0.22))
                    .lineLimit(2)
                if !product.skinTypes.isEmpty {
                    Text(product.skinTypes.joined(separator: ", ").capitalized)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Button { productForSaveSheet = product } label: {
                    Image(systemName: isBoarded ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            isBoarded
                                ? Color(red: 0.34, green: 0.53, blue: 0.52)
                                : Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.4)
                        )
                        .frame(width: 44, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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
                        .frame(width: 44, height: 30)
                        .contentShape(Rectangle())
                        .scaleEffect(isLiked ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isLiked)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    // MARK: - Data

    private func loadLikedProductNames() async {
        async let liked   = try? likedService.fetchLikedProductNames()
        async let boarded = try? boardsService.fetchBoardedProductNames()
        likedProductNames   = await liked ?? []
        boardedProductNames = await boarded ?? []
    }

    private func performSearch(query: String) async {
        do {
            let results = try await searchService.search(query: query)
            searchResults = results
            isSearching = false
        } catch {
            searchResults = []
            isSearching = false
        }
    }

    private func toggleLike(for product: RecommendedProduct) async {
        let wasLiked = likedProductNames.contains(product.name)
        if wasLiked { likedProductNames.remove(product.name) }
        else { likedProductNames.insert(product.name) }
        do {
            _ = try await likedService.toggleLike(productName: product.name, currentlyLiked: wasLiked)
        } catch {
            if wasLiked { likedProductNames.insert(product.name) }
            else { likedProductNames.remove(product.name) }
        }
    }
}
