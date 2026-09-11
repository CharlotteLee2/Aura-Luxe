import SwiftUI

struct RoutineBuilderView: View {
    private let service = HabitTrackerService()
    @Environment(\.dismiss) private var dismiss

    @State private var allSteps: [RoutineStep] = []
    @State private var selectedTime: RoutineBuilderTab = .am
    @State private var showAddSheet = false
    @State private var isLoading = true
    @State private var isSavingOrder = false

    private let teal = Color(red: 0.30, green: 0.63, blue: 0.55)
    private let textDark = Color(red: 0.14, green: 0.20, blue: 0.20)
    private let textMid = Color(red: 0.39, green: 0.48, blue: 0.48)
    private let border = Color(red: 0.78, green: 0.88, blue: 0.88)

    private var displayedSteps: [RoutineStep] {
        allSteps.filter { step in
            switch selectedTime {
            case .am: return step.time_of_use == "am" || step.time_of_use == "both"
            case .pm: return step.time_of_use == "pm" || step.time_of_use == "both"
            }
        }
    }

    var body: some View {
        NavigationStack {
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
                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(teal)
                        Spacer()
                    } else if displayedSteps.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(displayedSteps) { step in
                                stepRow(step)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            }
                            .onMove(perform: moveSteps)
                            .onDelete(perform: deleteSteps)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Build Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(teal)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(teal)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Product")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(teal)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddToRoutineSheet(productName: "", onAdded: {
                Task { await loadSteps() }
            })
        }
        .task { await loadSteps() }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("☀️  AM Routine", tab: .am)
            tabButton("🌙  PM Routine", tab: .pm)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.6)))
    }

    private func tabButton(_ label: String, tab: RoutineBuilderTab) -> some View {
        let selected = selectedTime == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTime = tab }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selected ? teal : textMid)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selected
                        ? RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        : nil
                )
        }
        .buttonStyle(.plain)
        .padding(4)
    }

    // MARK: - Step row

    private func stepRow(_ step: RoutineStep) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textMid.opacity(0.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(step.product_name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    frequencyBadge(step.frequencyBadge)
                    if let days = step.days_of_week, !days.isEmpty {
                        Text(days.map { String($0.prefix(1)).uppercased() }.joined(separator: "·"))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(textMid)
                    }
                    timeBadge(step.time_of_use)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
    }

    private func frequencyBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(teal.opacity(0.12)))
    }

    private func timeBadge(_ time: String) -> some View {
        let label: String
        switch time {
        case "am":   label = "AM"
        case "pm":   label = "PM"
        default:     label = "AM+PM"
        }
        return Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(red: 0.90, green: 0.95, blue: 0.95)))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: selectedTime == .am ? "sun.max" : "moon.stars")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(teal.opacity(0.5))
            Text("No \(selectedTime == .am ? "AM" : "PM") products yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textDark)
            Text("Tap + Add Product below to build your routine.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(textMid)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func loadSteps() async {
        isLoading = true
        allSteps = (try? await service.fetchRoutineSteps()) ?? []
        isLoading = false
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        var mutable = displayedSteps
        mutable.move(fromOffsets: source, toOffset: destination)
        // Update step_order only for the reordered (displayed) steps
        for (index, step) in mutable.enumerated() {
            if let i = allSteps.firstIndex(where: { $0.id == step.id }) {
                allSteps[i].step_order = index
            }
        }
        Task { try? await service.updateStepOrder(steps: mutable) }
    }

    private func deleteSteps(at offsets: IndexSet) {
        let toDelete = offsets.map { displayedSteps[$0] }
        for step in toDelete {
            allSteps.removeAll { $0.id == step.id }
            Task { try? await service.deleteRoutineStep(id: step.id) }
        }
    }
}

private enum RoutineBuilderTab { case am, pm }
