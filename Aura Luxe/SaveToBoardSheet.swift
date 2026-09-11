import SwiftUI

struct SaveToBoardSheet: View {
    let productName: String

    @Environment(\.dismiss) private var dismiss
    @State private var boards: [Board] = []
    @State private var savedBoardIDs: Set<UUID> = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isCreatingBoard = false
    @State private var newBoardName = ""
    @State private var showAddToRoutineSheet = false
    @FocusState private var newBoardFocused: Bool

    private let boardsService = BoardsService()

    private var filteredBoards: [Board] {
        guard !searchText.isEmpty else { return boards }
        return boards.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.98, blue: 0.97),
                        Color(red: 0.88, green: 0.94, blue: 0.95),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Divider()
                        .overlay(Color(red: 0.78, green: 0.88, blue: 0.88))

                    if isLoading {
                        Spacer()
                        ProgressView().tint(Color(red: 0.30, green: 0.63, blue: 0.55))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(filteredBoards) { board in
                                    boardRow(board)
                                    Divider()
                                        .overlay(Color(red: 0.78, green: 0.88, blue: 0.88))
                                        .padding(.leading, 68)
                                }

                                if isCreatingBoard {
                                    createBoardRow
                                }

                                createBoardButton
                                    .padding(.top, isCreatingBoard ? 0 : 4)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Save to board")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showAddToRoutineSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Add to Routine")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                    }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddToRoutineSheet) {
            AddToRoutineSheet(productName: productName)
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search boards...")
                    .foregroundColor(Color(red: 0.39, green: 0.48, blue: 0.48))
            )
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    private func boardRow(_ board: Board) -> some View {
        let isSaved = savedBoardIDs.contains(board.id)
        return Button {
            toggleBoard(board)
        } label: {
            HStack(spacing: 14) {
                boardThumbnail(board)

                Text(board.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

                Spacer()

                if isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(red: 0.78, green: 0.88, blue: 0.88))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func boardThumbnail(_ board: Board) -> some View {
        Group {
            if let urlString = board.coverImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(red: 0.82, green: 0.90, blue: 0.90)
                }
            } else {
                Color(red: 0.82, green: 0.90, blue: 0.90)
                    .overlay(
                        Image(systemName: "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.6))
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var createBoardRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                )

            TextField("Board name", text: $newBoardName)
                .font(.system(size: 16, design: .rounded))
                .focused($newBoardFocused)
                .submitLabel(.done)
                .onSubmit { Task { await submitNewBoard() } }
                .autocorrectionDisabled()

            if !newBoardName.isEmpty {
                Button {
                    Task { await submitNewBoard() }
                } label: {
                    Text("Create")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var createBoardButton: some View {
        Button {
            withAnimation { isCreatingBoard = true }
            newBoardFocused = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                }
                Text("Create new board")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isCreatingBoard ? 0 : 1)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        async let boards = try? boardsService.fetchBoards()
        async let savedIDs = try? boardsService.boardIDsContaining(productName: productName)
        self.boards = await boards ?? []
        self.savedBoardIDs = await savedIDs ?? []
        isLoading = false
    }

    private func toggleBoard(_ board: Board) {
        let wasSaved = savedBoardIDs.contains(board.id)
        if wasSaved {
            savedBoardIDs.remove(board.id)
        } else {
            savedBoardIDs.insert(board.id)
        }
        Task {
            do {
                if wasSaved {
                    try await boardsService.removeProduct(productName: productName, fromBoardID: board.id)
                } else {
                    try await boardsService.addProduct(productName: productName, toBoardID: board.id)
                }
            } catch {
                if wasSaved { savedBoardIDs.insert(board.id) }
                else { savedBoardIDs.remove(board.id) }
            }
        }
    }

    private func submitNewBoard() async {
        let trimmed = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let board = try await boardsService.createBoard(name: trimmed)
            try await boardsService.addProduct(productName: productName, toBoardID: board.id)
            var newBoard = board
            newBoard.productCount = 1
            boards.append(newBoard)
            savedBoardIDs.insert(board.id)
            newBoardName = ""
            withAnimation { isCreatingBoard = false }
        } catch {
            // board name conflict or network error — leave field open
        }
    }
}
