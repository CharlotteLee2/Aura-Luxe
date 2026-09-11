import SwiftUI

struct MyProductsPageView: View {
    private enum Tab { case liked, boards }

    @State private var selectedTab: Tab = .liked
    @State private var likedProducts: [RecommendedProduct] = []
    @State private var likedProductNames: Set<String> = []
    @State private var boardedProductNames: Set<String> = []
    @State private var boards: [Board] = []
    @State private var isLoadingLiked = true
    @State private var isLoadingBoards = true
    @State private var didInitialLoad = false
    @State private var productForSaveSheet: RecommendedProduct? = nil
    @State private var productForRoutineSheet: RecommendedProduct? = nil
    @State private var selectedBoard: Board? = nil

    private let likedService = LikedProductsService()
    private let boardsService = BoardsService()

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
                        tabSelector
                        tabContent
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
            await loadAll()
        }
        .onAppear {
            guard didInitialLoad else { return }
            Task { boards = (try? await boardsService.fetchBoards()) ?? [] }
        }
        .sheet(item: $productForSaveSheet, onDismiss: {
            Task {
                async let names = try? boardsService.fetchBoardedProductNames()
                async let b = try? boardsService.fetchBoards()
                boardedProductNames = (await names) ?? []
                boards = (await b) ?? []
            }
        }) { product in
            SaveToBoardSheet(productName: product.name)
        }
        .sheet(item: $productForRoutineSheet) { product in
            AddToRoutineSheet(productName: product.name)
        }
        .sheet(item: $selectedBoard) { board in
            BoardDetailView(board: board)
        }
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack {
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

            Spacer()

            Text("My Products")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

            Spacer()

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

    // MARK: - Tab selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Liked", tab: .liked)
            tabButton("Boards", tab: .boards)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.6))
        )
    }

    private func tabButton(_ label: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(
                    isSelected
                        ? Color(red: 0.34, green: 0.53, blue: 0.52)
                        : Color(red: 0.39, green: 0.48, blue: 0.48)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        : nil
                )
        }
        .buttonStyle(.plain)
        .padding(4)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .liked:
            likedSection
        case .boards:
            boardsSection
        }
    }

    // MARK: - Liked tab

    @ViewBuilder
    private var likedSection: some View {
        if isLoadingLiked {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in shimmerCard }
            }
        } else if likedProducts.isEmpty {
            emptyLikedState
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

    private var emptyLikedState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 48)
            Image(systemName: "heart")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.45))
            Text("No saved products yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            Text("Tap the heart on any product to save it here.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }

    private func likedProductCard(_ product: RecommendedProduct) -> some View {
        let isBoarded = boardedProductNames.contains(product.name)
        return HStack(spacing: 14) {
            Group {
                if let urlString = product.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(red: 0.82, green: 0.90, blue: 0.90)
                    }
                } else {
                    Color(red: 0.82, green: 0.90, blue: 0.90)
                        .overlay(Image(systemName: "sparkles").foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.6)))
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

                Button { Task { await unlike(product: product) } } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                        .frame(width: 44, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
        .contextMenu {
            Button {
                productForRoutineSheet = product
            } label: {
                Label("Add to Routine", systemImage: "plus.circle")
            }
            Button {
                productForSaveSheet = product
            } label: {
                Label("Save to Board", systemImage: "bookmark")
            }
            Button(role: .destructive) {
                Task { await unlike(product: product) }
            } label: {
                Label("Remove from Liked", systemImage: "heart.slash")
            }
        }
    }

    // MARK: - Boards tab

    @ViewBuilder
    private var boardsSection: some View {
        if isLoadingBoards {
            VStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in shimmerCard }
            }
        } else if boards.isEmpty {
            emptyBoardsState
        } else {
            boardsMasonryGrid
        }
    }

    private var emptyBoardsState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 48)
            Image(systemName: "bookmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.45))
            Text("No boards yet")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            Text("Tap the bookmark on any product to create your first board.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }

    private var boardsMasonryGrid: some View {
        let leftBoards = boards.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let rightBoards = boards.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                ForEach(leftBoards) { board in
                    boardCard(board, tall: true)
                }
            }
            VStack(spacing: 12) {
                ForEach(rightBoards) { board in
                    boardCard(board, tall: false)
                }
            }
            .padding(.top, 28)
        }
    }

    private func boardCard(_ board: Board, tall: Bool) -> some View {
        Button { selectedBoard = board } label: {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let urlString = board.coverImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                            Color(red: 0.82, green: 0.90, blue: 0.90)
                        }
                    } else {
                        Color(red: 0.82, green: 0.90, blue: 0.90)
                            .overlay(
                                Image(systemName: "bookmark")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.5))
                            )
                    }
                }
                .frame(height: tall ? 180 : 140)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(board.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                        .lineLimit(1)
                    Text("\(board.productCount) product\(board.productCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") {
                // Trigger rename via BoardDetailView — open the board
                selectedBoard = board
            }
            Button("Delete", role: .destructive) {
                Task { await deleteBoard(board) }
            }
        }
    }

    // MARK: - Shared shimmer

    private var shimmerCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                .frame(width: 86, height: 96)
                .overlay(Image(systemName: "sparkles").foregroundStyle(Color.white.opacity(0.9)))
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.72, green: 0.82, blue: 0.82)).frame(width: 86, height: 18)
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.82, green: 0.90, blue: 0.90)).frame(width: 140, height: 14)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    // MARK: - Data

    private func loadAll() async {
        async let liked = try? likedService.fetchLikedProducts()
        async let boardsFetch = try? boardsService.fetchBoards()
        async let boardedNames = try? boardsService.fetchBoardedProductNames()

        let (l, b, bn) = await (liked, boardsFetch, boardedNames)
        let products = l ?? []
        likedProducts = products
        likedProductNames = Set(products.map(\.name))
        boards = b ?? []
        boardedProductNames = bn ?? []
        isLoadingLiked = false
        isLoadingBoards = false
    }

    private func unlike(product: RecommendedProduct) async {
        likedProductNames.remove(product.name)
        withAnimation { likedProducts.removeAll { $0.name == product.name } }
        do {
            try await likedService.unlike(productName: product.name)
        } catch {
            likedProducts.insert(product, at: 0)
            likedProductNames.insert(product.name)
        }
    }

    private func deleteBoard(_ board: Board) async {
        withAnimation { boards.removeAll { $0.id == board.id } }
        do {
            try await boardsService.deleteBoard(id: board.id)
        } catch {
            boards.append(board)
        }
    }
}
