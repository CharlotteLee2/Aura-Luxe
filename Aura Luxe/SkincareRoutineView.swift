import SwiftUI

private enum TimeOfUse: String, CaseIterable {
    case morning, night, both

    var label: String {
        switch self {
        case .morning: return "AM"
        case .night: return "PM"
        case .both: return "Both"
        }
    }
}

private struct RoutineEntry: Identifiable {
    let id = UUID()
    let productName: String
    var timeOfUse: TimeOfUse = .both
}

struct SkincareRoutineView: View {
    private let onCompletion: () -> Void
    private let searchService = ProductSearchService()
    private let routineService = SkincareRoutineService()

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var searchResults: [RecommendedProduct] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var addedProducts: [RoutineEntry] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
    }

    private var showDropdown: Bool {
        searchFocused && !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerSection
                                .padding(.top, 56)
                                .padding(.bottom, 28)

                            searchSection
                                .padding(.bottom, 8)

                            if showDropdown {
                                dropdownSection
                                    .padding(.bottom, 8)
                            }

                            if !addedProducts.isEmpty {
                                addedProductsList
                                    .padding(.top, 8)
                            }

                            Spacer(minLength: 120)
                        }
                        .frame(maxWidth: min(geometry.size.width - 40, 430))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    bottomSection
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showDropdown)
        .animation(.easeInOut(duration: 0.18), value: addedProducts.count)
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Add products you currently use")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.18))

            Text("We'll use this to build your routine")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.38, green: 0.47, blue: 0.47))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))

            TextField("Search for a product...", text: $searchText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    searchFocused = false
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
                            searchFocused
                                ? Color(red: 0.34, green: 0.53, blue: 0.52).opacity(0.5)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Dropdown

    private var dropdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            } else {
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                let alreadyAdded = Set(addedProducts.map { $0.productName.lowercased() })

                ForEach(Array(searchResults.prefix(5).enumerated()), id: \.element.id) { index, product in
                    if !alreadyAdded.contains(product.name.lowercased()) {
                        VStack(spacing: 0) {
                            if index > 0 { Divider().padding(.horizontal, 14) }
                            dropdownRow(label: product.name, isAddRow: false)
                        }
                    }
                }

                if !trimmed.isEmpty && !alreadyAdded.contains(trimmed.lowercased()) {
                    let exactMatch = searchResults.prefix(5).contains(where: {
                        $0.name.lowercased() == trimmed.lowercased()
                    })
                    if !exactMatch {
                        if !searchResults.isEmpty { Divider().padding(.horizontal, 14) }
                        dropdownRow(label: "Add \"\(trimmed)\"", isAddRow: true, freeText: trimmed)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.97))
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        )
    }

    private func dropdownRow(label: String, isAddRow: Bool, freeText: String? = nil) -> some View {
        Button {
            let name = freeText ?? label
            addProduct(name: name)
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: isAddRow ? .medium : .regular, design: .rounded))
                    .foregroundStyle(
                        isAddRow
                            ? Color(red: 0.30, green: 0.63, blue: 0.55)
                            : Color(red: 0.14, green: 0.20, blue: 0.20)
                    )
                Spacer()
                if isAddRow {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Added products list

    private var addedProductsList: some View {
        VStack(spacing: 10) {
            ForEach($addedProducts) { $entry in
                productCard(entry: $entry)
            }
        }
    }

    private func productCard(entry: Binding<RoutineEntry>) -> some View {
        HStack(spacing: 12) {
            Text(entry.wrappedValue.productName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.11, green: 0.18, blue: 0.17))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            timeToggle(selection: entry.timeOfUse)

            Button {
                withAnimation {
                    addedProducts.removeAll { $0.id == entry.wrappedValue.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.60, blue: 0.60))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(red: 0.90, green: 0.94, blue: 0.94)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.76, green: 0.86, blue: 0.86), lineWidth: 1)
        )
    }

    private func timeToggle(selection: Binding<TimeOfUse>) -> some View {
        HStack(spacing: 0) {
            ForEach(TimeOfUse.allCases, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : Color(red: 0.38, green: 0.47, blue: 0.47)
                        )
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color(red: 0.30, green: 0.63, blue: 0.55) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.90, green: 0.95, blue: 0.95))
        )
    }

    // MARK: - Bottom

    private var bottomSection: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button {
                Task { await saveAndComplete() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .background(Color(red: 0.30, green: 0.63, blue: 0.55))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .disabled(isSaving)
            .opacity(isSaving ? 0.65 : 1)
            .padding(.horizontal, 20)

            Button {
                onCompletion()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.38, green: 0.47, blue: 0.47))
                    .frame(height: 36)
            }
        }
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.99, blue: 0.97).opacity(0),
                    Color(red: 0.95, green: 0.99, blue: 0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Actions

    private func addProduct(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !addedProducts.contains(where: { $0.productName.lowercased() == trimmed.lowercased() }) else { return }
        addedProducts.append(RoutineEntry(productName: trimmed))
        searchText = ""
        searchResults = []
        searchFocused = false
    }

    private func performSearch(query: String) async {
        do {
            let results = try await searchService.search(query: query)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }

    private func saveAndComplete() async {
        guard !addedProducts.isEmpty else {
            onCompletion()
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let userID = try await routineService.authenticatedUserID()
            let entries = addedProducts.map {
                SkincareRoutineEntry(
                    user_id: userID,
                    product_name: $0.productName,
                    time_of_use: $0.timeOfUse.rawValue
                )
            }
            try await routineService.save(entries: entries)
            await MainActor.run { onCompletion() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
