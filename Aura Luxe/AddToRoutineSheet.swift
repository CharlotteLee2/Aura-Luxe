import SwiftUI

struct AddToRoutineSheet: View {
    // Pass a non-empty productName to skip search. Pass "" to show inline search.
    let productName: String
    var onAdded: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private let service = HabitTrackerService()
    private let searchService = ProductSearchService()

    @State private var resolvedName: String = ""
    @State private var searchText: String = ""
    @State private var searchResults: [RecommendedProduct] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var searchFocused: Bool

    @State private var timeOfUse: String = "am"
    @State private var frequency: RoutineFrequency = .daily
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var isSaving = false
    @State private var error: String?

    private var isSearchMode: Bool { productName.isEmpty }
    private var effectiveName: String { isSearchMode ? resolvedName : productName }

    private let teal = Color(red: 0.30, green: 0.63, blue: 0.55)
    private let textDark = Color(red: 0.14, green: 0.20, blue: 0.20)
    private let textMid = Color(red: 0.39, green: 0.48, blue: 0.48)
    private let border = Color(red: 0.78, green: 0.88, blue: 0.88)

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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Product name header / search
                        VStack(spacing: 10) {
                            Text("Add to Routine")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(textDark)

                            if isSearchMode {
                                searchField
                                if !searchResults.isEmpty || isSearching {
                                    searchDropdown
                                }
                                if !resolvedName.isEmpty {
                                    Text(resolvedName)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(teal)
                                }
                            } else {
                                Text(productName)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(teal)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 8)

                        // Time of use
                        sectionCard(title: "When do you use it?") {
                            HStack(spacing: 0) {
                                timeButton("AM", value: "am")
                                timeButton("PM", value: "pm")
                                timeButton("Both", value: "both")
                            }
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.90, green: 0.95, blue: 0.95)))
                        }

                        // Frequency
                        sectionCard(title: "How often?") {
                            VStack(spacing: 0) {
                                ForEach(RoutineFrequency.allCases, id: \.self) { option in
                                    frequencyRow(option)
                                    if option != RoutineFrequency.allCases.last {
                                        Divider().overlay(border.opacity(0.5)).padding(.horizontal, 4)
                                    }
                                }
                            }
                        }

                        // Days of week (conditional)
                        if frequency.needsDayPicker {
                            sectionCard(title: "Which days?") {
                                dayPicker
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }

                        addButton
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(teal)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.2), value: frequency)
    }

    // MARK: - Time toggle

    private func timeButton(_ label: String, value: String) -> some View {
        let selected = timeOfUse == value
        return Button { timeOfUse = value } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? .white : textMid)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? teal : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Frequency row

    private func frequencyRow(_ option: RoutineFrequency) -> some View {
        Button { frequency = option } label: {
            HStack {
                Text(option.label)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(textDark)
                Spacer()
                if frequency == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(teal)
                } else {
                    Circle()
                        .strokeBorder(border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day picker

    private var dayPicker: some View {
        HStack(spacing: 6) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                let selected = selectedDays.contains(day)
                Button {
                    if selected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                } label: {
                    Text(day.label.prefix(2).description)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? .white : textMid)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected ? teal : Color(red: 0.90, green: 0.95, blue: 0.95))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section card

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(textMid)
                .tracking(0.8)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
    }

    // MARK: - Search components (for search mode)

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
            TextField("Search for a product...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(textDark)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    resolvedName = ""
                    searchTask?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { searchResults = []; isSearching = false; return }
                    isSearching = true
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        let results = (try? await searchService.search(query: trimmed)) ?? []
                        searchResults = results
                        isSearching = false
                    }
                }
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = []; resolvedName = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(textMid.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.9)))
        .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    private var searchDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSearching {
                HStack { ProgressView().scaleEffect(0.8); Text("Searching...").font(.system(size: 14, design: .rounded)).foregroundStyle(textMid) }
                    .padding(12)
            } else {
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { i, product in
                    if i > 0 { Divider().padding(.horizontal, 12) }
                    Button { pick(product.name) } label: {
                        Text(product.name)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(textDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if !trimmed.isEmpty {
                    if !searchResults.isEmpty { Divider().padding(.horizontal, 12) }
                    Button { pick(trimmed) } label: {
                        HStack {
                            Text("Add \"\(trimmed)\"")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(teal)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(teal)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.97)).shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3))
    }

    private func pick(_ name: String) {
        resolvedName = name
        searchText = name
        searchResults = []
        searchFocused = false
    }

    // MARK: - Add button

    private var isAddDisabled: Bool {
        isSaving
            || (frequency.needsDayPicker && selectedDays.isEmpty)
            || (isSearchMode && effectiveName.isEmpty)
    }

    private var addButton: some View {
        Button {
            Task { await save() }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Add to Routine")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 20).fill(teal))
        }
        .disabled(isAddDisabled)
        .opacity(isAddDisabled ? 0.5 : 1)
    }

    // MARK: - Save

    private func save() async {
        let name = effectiveName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSaving = true
        error = nil
        do {
            let existing = try await service.fetchRoutineSteps()
            let days = frequency.needsDayPicker ? selectedDays.map(\.rawValue) : nil
            _ = try await service.addRoutineStep(
                productName: name,
                timeOfUse: timeOfUse,
                frequency: frequency,
                daysOfWeek: days,
                existingCount: existing.count
            )
            onAdded?()
            dismiss()
        } catch {
            self.error = "Couldn't add to routine. Please try again."
        }
        isSaving = false
    }
}
