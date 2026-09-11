import SwiftUI

struct BoardDetailView: View {
    @State var board: Board
    @Environment(\.dismiss) private var dismiss

    @State private var products: [RecommendedProduct] = []
    @State private var isLoading = true
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool

    private let boardsService = BoardsService()
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
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if isLoading {
                            ForEach(0..<3, id: \.self) { _ in shimmerCard }
                        } else if products.isEmpty {
                            emptyState
                        } else {
                            ForEach(products) { product in
                                productRow(product)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
            }
        }
        .task { await loadProducts() }
        .alert("Rename board", isPresented: $isRenaming) {
            TextField("Board name", text: $renameText)
            Button("Save") { Task { await saveRename() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(board.name)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                .lineLimit(1)

            Spacer()

            Menu {
                Button("Rename") {
                    renameText = board.name
                    isRenaming = true
                }
                Button("Delete board", role: .destructive) {
                    Task { await deleteBoard() }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Product row

    private func productRow(_ product: RecommendedProduct) -> some View {
        HStack(spacing: 14) {
            Group {
                if let urlString = product.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(red: 0.82, green: 0.90, blue: 0.90)
                    }
                } else {
                    Color(red: 0.82, green: 0.90, blue: 0.90)
                        .overlay(Image(systemName: "sparkles").foregroundStyle(Color.white.opacity(0.9)))
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

            Button {
                Task { await removeFromBoard(product: product) }
            } label: {
                Image(systemName: "bookmark.fill")
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

    private var shimmerCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                .frame(width: 86, height: 96)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 48)
            Image(systemName: "bookmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.4))
            Text("No products yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            Text("Tap the bookmark on any product to add it to this board.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await boardsService.fetchProducts(inBoardID: board.id)) ?? []
    }

    private func removeFromBoard(product: RecommendedProduct) async {
        withAnimation { products.removeAll { $0.name == product.name } }
        do {
            try await boardsService.removeProduct(productName: product.name, fromBoardID: board.id)
            board.productCount = max(0, board.productCount - 1)
        } catch {
            products.insert(product, at: 0)
        }
    }

    private func saveRename() async {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != board.name else { return }
        do {
            try await boardsService.renameBoard(id: board.id, newName: trimmed)
            board = Board(id: board.id, name: trimmed, productCount: board.productCount, coverImageURL: board.coverImageURL)
        } catch {}
    }

    private func deleteBoard() async {
        do {
            try await boardsService.deleteBoard(id: board.id)
            dismiss()
        } catch {}
    }
}
