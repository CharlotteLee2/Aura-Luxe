import SwiftUI

struct HabitTrackerPageView: View {
    private let service = HabitTrackerService()

    @State private var routineSteps: [RoutineStep] = []
    @State private var todayLogs: [HabitLog] = []
    @State private var streakInfo = StreakInfo(currentStreak: 0, longestStreak: 0, weeklyCompletionCount: 0, amCompleted: false, pmCompleted: false)
    @State private var skinProfile = SkinProfile.empty
    @State private var routineConflicts: [IngredientConflict] = []
    @State private var irritationLogs: [IrritationLog] = []
    @State private var progressPhotos: [ProgressPhoto] = []
    @State private var selectedDate = Date()

    @State private var isLoading = true
    @State private var showRoutineBuilder = false
    @State private var showIrritationSheet = false
    @State private var showPhotoSheet = false
    @State private var showAddToRoutineSheet = false
    @State private var amExpanded = true
    @State private var pmExpanded = true
    @State private var dismissedTips: Set<String> = []

    private let teal = Color(red: 0.30, green: 0.63, blue: 0.55)
    private let tealDark = Color(red: 0.22, green: 0.52, blue: 0.46)
    private let textDark = Color(red: 0.14, green: 0.20, blue: 0.20)
    private let textMid = Color(red: 0.39, green: 0.48, blue: 0.48)
    private let border = Color(red: 0.78, green: 0.88, blue: 0.88)

    private var amSteps: [RoutineStep] {
        routineSteps.filter { $0.time_of_use == "am" || $0.time_of_use == "both" }
    }
    private var pmSteps: [RoutineStep] {
        routineSteps.filter { $0.time_of_use == "pm" || $0.time_of_use == "both" }
    }
    private var completionPct: Double {
        service.todayCompletionPct(steps: routineSteps, logs: todayLogs, date: selectedDate)
    }

    // MARK: - Body

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

            if isLoading {
                ProgressView().tint(teal)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topRow
                        progressCard
                        statsRow
                        conflictWarnings
                        routineSection(
                            title: "☀️  AM Routine",
                            steps: amSteps,
                            timeKey: "am",
                            isExpanded: $amExpanded
                        )
                        routineSection(
                            title: "🌙  PM Routine",
                            steps: pmSteps,
                            timeKey: "pm",
                            isExpanded: $pmExpanded
                        )
                        recommendationTips
                        myProductsSection
                        irritationSection
                        progressPhotosSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await loadAll() }
        .sheet(isPresented: $showRoutineBuilder) {
            RoutineBuilderView()
                .onDisappear { Task { await loadAll() } }
        }
        .sheet(isPresented: $showIrritationSheet) {
            IrritationLogSheet(onSaved: {
                Task { irritationLogs = (try? await service.fetchRecentIrritationLogs()) ?? [] }
            })
        }
        .sheet(isPresented: $showPhotoSheet) {
            PhotoPickerSheet(service: service, onUploaded: {
                Task { progressPhotos = (try? await service.fetchProgressPhotos()) ?? [] }
            })
        }
        .sheet(isPresented: $showAddToRoutineSheet) {
            AddToRoutineSheet(productName: "", onAdded: {
                Task { await loadAll() }
            })
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Skincare")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(textDark)
                if !skinProfile.skinType.isEmpty {
                    Text("\(skinProfile.skinType) · \(skinProfile.experience)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textMid)
                }
            }
            Spacer()
            Button { showRoutineBuilder = true } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(teal)
                    )
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [teal, tealDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: teal.opacity(0.35), radius: 12, x: 0, y: 6)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Progress")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("\(Int(completionPct * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                circularProgress(pct: completionPct)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }

    private func circularProgress(pct: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 10)
                .frame(width: 90, height: 90)

            Circle()
                .trim(from: 0, to: pct)
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: pct)

            VStack(spacing: 2) {
                Text(streakInfo.amCompleted ? "✓" : "–")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("AM")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(streakInfo.pmCompleted ? "✓" : "–")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("PM")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "flame.fill",
                iconColor: Color(red: 0.95, green: 0.50, blue: 0.20),
                label: "Streak",
                value: "\(streakInfo.currentStreak)",
                subtitle: "days"
            )
            statCard(
                icon: "calendar",
                iconColor: teal,
                label: "This Week",
                value: "\(streakInfo.weeklyCompletionCount)/7",
                subtitle: "\(Int(streakInfo.weeklyPct * 100))%"
            )
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(iconColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMid)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(textDark)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(textMid)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
    }

    // MARK: - Conflict Warnings

    @ViewBuilder
    private var conflictWarnings: some View {
        if !routineConflicts.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(routineConflicts.enumerated()), id: \.offset) { _, conflict in
                    conflictBanner(conflict)
                }
            }
        }
    }

    private func conflictBanner(_ conflict: IngredientConflict) -> some View {
        let isAvoid = conflict.severity == .avoid
        let bg = isAvoid ? Color(red: 0.99, green: 0.92, blue: 0.90) : Color(red: 0.98, green: 0.95, blue: 0.84)
        let fg = isAvoid ? Color(red: 0.75, green: 0.20, blue: 0.16) : Color(red: 0.72, green: 0.50, blue: 0.08)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isAvoid ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(fg)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(conflict.ingredientA) + \(conflict.ingredientB)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                Text(conflict.message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(textMid)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(bg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(fg.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Routine Section

    private func routineSection(title: String, steps: [RoutineStep], timeKey: String, isExpanded: Binding<Bool>) -> some View {
        let log = todayLogs.first(where: { $0.time_of_use == timeKey })
        let isCompleted = log?.completed == true
        let isSkipped = log?.skipped == true

        return VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(textDark)

                    Spacer()

                    if isCompleted {
                        completedBadge
                    } else if isSkipped {
                        skippedBadge
                    } else {
                        Text("\(steps.count) step\(steps.count == 1 ? "" : "s")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(textMid)
                    }

                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textMid)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                Divider().overlay(border.opacity(0.5)).padding(.horizontal, 16)

                VStack(spacing: 0) {
                    if steps.isEmpty {
                        Button { showRoutineBuilder = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Add \(timeKey.uppercased()) products")
                            }
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(teal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(steps) { step in
                            checklistRow(step: step, timeKey: timeKey)
                            if step.id != steps.last?.id {
                                Divider().overlay(border.opacity(0.4)).padding(.horizontal, 16)
                            }
                        }

                        // Complete / Skip row
                        if !isCompleted && !isSkipped {
                            Divider().overlay(border.opacity(0.5)).padding(.horizontal, 16)
                            HStack(spacing: 10) {
                                Button { Task { await markRoutine(timeKey: timeKey, completed: true) } } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Complete \(timeKey.uppercased())")
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(teal))
                                }
                                .buttonStyle(.plain)

                                Button { Task { await markRoutine(timeKey: timeKey, completed: false) } } label: {
                                    Text("Skip")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(textMid)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.92, green: 0.95, blue: 0.95)))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(timeKey == "am"
                    ? Color(red: 0.93, green: 0.98, blue: 0.96).opacity(0.95)
                    : Color(red: 0.94, green: 0.92, blue: 0.99).opacity(0.95))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }

    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
            Text("Done")
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.20, green: 0.65, blue: 0.45))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(red: 0.90, green: 0.97, blue: 0.93)))
    }

    private var skippedBadge: some View {
        Text("Skipped")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(textMid)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(red: 0.90, green: 0.93, blue: 0.93)))
    }

    private func checklistRow(step: RoutineStep, timeKey: String) -> some View {
        HStack(spacing: 12) {
            let logForTime = todayLogs.first(where: { $0.time_of_use == timeKey })
            let isRoutineCompleted = logForTime?.completed == true
            Image(systemName: isRoutineCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isRoutineCompleted ? teal : border)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.product_name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                    .lineLimit(1)
                if step.frequency != "daily" {
                    overuseWarning(step: step) ?? AnyView(
                        Text(step.frequencyBadge)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(textMid)
                    )
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func overuseWarning(step: RoutineStep) -> AnyView? {
        let name = step.product_name.lowercased()
        let freq = step.frequencyEnum
        let keywords: [(keyword: String, maxFreq: RoutineFrequency)] = [
            ("retinol", .threePerWeek),
            ("glycolic", .threePerWeek),
            ("lactic acid", .threePerWeek),
            ("salicylic", .threePerWeek),
            ("aha", .threePerWeek),
            ("bha", .threePerWeek),
            ("exfoliant", .threePerWeek),
            ("peeling", .threePerWeek),
        ]
        guard let match = keywords.first(where: { name.contains($0.keyword) }) else { return nil }
        guard freq == .daily else { return nil }
        return AnyView(
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("\(match.keyword.capitalized) daily may over-exfoliate — try \(match.maxFreq.label.lowercased())")
                    .font(.system(size: 11, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.80, green: 0.50, blue: 0.10))
        )
    }

    // MARK: - Recommendation Tips

    @ViewBuilder
    private var recommendationTips: some View {
        let tips = buildTips()
        if !tips.isEmpty {
            VStack(spacing: 8) {
                ForEach(tips, id: \.id) { tip in
                    if !dismissedTips.contains(tip.id) {
                        tipCard(tip)
                    }
                }
            }
        }
    }

    private func buildTips() -> [RoutineTip] {
        var tips: [RoutineTip] = []
        let allNames = routineSteps.map { $0.product_name.lowercased() }
        let hasSPF = allNames.contains { $0.contains("spf") || $0.contains("sunscreen") || $0.contains("sun protection") }
        let hasMoisturizer = allNames.contains { $0.contains("moistur") || $0.contains("cream") || $0.contains("lotion") || $0.contains("hydrat") }
        let hasBHA = allNames.contains { $0.contains("salicylic") || $0.contains("bha") }
        let hasToner = allNames.contains { $0.contains("toner") || $0.contains("tonic") }

        if skinProfile.concerns.contains(where: { $0.lowercased() == "acne" }) && !hasBHA {
            tips.append(RoutineTip(id: "bha", icon: "lightbulb.fill", message: "You listed Acne as a concern — consider adding a BHA (salicylic acid) 2–3×/week."))
        }
        if (skinProfile.concerns.contains(where: { $0.lowercased() == "dryness" }) || skinProfile.skinType == "Dry") && !hasMoisturizer {
            tips.append(RoutineTip(id: "moisturizer", icon: "drop.fill", message: "Your skin type may benefit from a dedicated moisturizer in your PM routine."))
        }
        if !hasSPF && !amSteps.isEmpty {
            tips.append(RoutineTip(id: "spf", icon: "sun.max.fill", message: "Don't forget SPF — it's an essential last step in your AM routine."))
        }
        if !hasToner && routineSteps.count >= 2 {
            tips.append(RoutineTip(id: "toner", icon: "sparkles", message: "Adding a toner can help balance skin pH and boost absorption of serums."))
        }
        return tips
    }

    private func tipCard(_ tip: RoutineTip) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tip.icon)
                .font(.system(size: 14))
                .foregroundStyle(teal)
                .padding(.top, 1)
            Text(tip.message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(textDark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { withAnimation { _ = dismissedTips.insert(tip.id) } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textMid)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.93, green: 0.97, blue: 0.96)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(teal, lineWidth: 1).opacity(0.25))
    }

    // MARK: - My Products

    private var myProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Products")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                Spacer()
                Button { showAddToRoutineSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(teal.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            if routineSteps.isEmpty {
                Text("No products in your routine yet. Tap + Add to get started.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(textMid)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(routineSteps) { step in
                            productChip(step)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }

    private func productChip(_ step: RoutineStep) -> some View {
        HStack(spacing: 6) {
            Text(step.time_of_use == "am" ? "☀️" : step.time_of_use == "pm" ? "🌙" : "✨")
                .font(.system(size: 12))
            Text(step.product_name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textDark)
                .lineLimit(1)
            Button {
                Task { try? await service.deleteRoutineStep(id: step.id)
                    routineSteps.removeAll { $0.id == step.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textMid)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
    }

    // MARK: - Irritation Log Section

    private var irritationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Irritation Log")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                Spacer()
                Button { showIrritationSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Log Today")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(teal.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            if irritationLogs.isEmpty {
                Text("No irritation logged recently. Tap + Log Today if you notice redness or discomfort.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(textMid)
            } else {
                VStack(spacing: 8) {
                    ForEach(irritationLogs.prefix(3)) { log in
                        irritationRow(log)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }

    private func irritationRow(_ log: IrritationLog) -> some View {
        let emoji: String
        switch log.severity {
        case 1: emoji = "😊"
        case 2: emoji = "😐"
        case 3: emoji = "😕"
        case 4: emoji = "😣"
        default: emoji = "😫"
        }
        return HStack(spacing: 10) {
            Text(emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate(log.log_date))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(textMid)
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= log.severity ? severityColor(log.severity) : border)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.96, green: 0.97, blue: 0.97)))
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 1, 2: return Color(red: 0.20, green: 0.65, blue: 0.45)
        case 3:    return Color(red: 0.85, green: 0.60, blue: 0.10)
        default:   return Color(red: 0.85, green: 0.30, blue: 0.25)
        }
    }

    // MARK: - Progress Photos Section

    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress Photos")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textDark)
                Spacer()
                Button { showPhotoSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(teal.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            if progressPhotos.isEmpty {
                Text("Track your skin's journey by adding weekly photos.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(textMid)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(progressPhotos.prefix(8)) { photo in
                            photoThumbnail(photo)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }

    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        VStack(spacing: 4) {
            Group {
                if let url = URL(string: photo.photo_url) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(red: 0.82, green: 0.90, blue: 0.90)
                    }
                } else {
                    Color(red: 0.82, green: 0.90, blue: 0.90)
                        .overlay(Image(systemName: "photo").foregroundStyle(.white))
                }
            }
            .frame(width: 80, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))

            Text(formattedDate(photo.captured_at))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(textMid)
                .lineLimit(1)
        }
    }

    // MARK: - Data Loading

    private func loadAll() async {
        isLoading = true
        await service.migrateFromLegacyRoutineIfNeeded()
        async let steps = try? service.fetchRoutineSteps()
        async let logs = try? service.fetchHabitLogs(for: selectedDate)
        async let streak = try? service.computeStreak(for: selectedDate)
        async let profile = try? service.loadSkinProfile()
        async let irritation = try? service.fetchRecentIrritationLogs()
        async let photos = try? service.fetchProgressPhotos()

        let (s, l, sk, p, ir, ph) = await (steps, logs, streak, profile, irritation, photos)
        routineSteps = s ?? []
        todayLogs = l ?? []
        streakInfo = sk ?? StreakInfo(currentStreak: 0, longestStreak: 0, weeklyCompletionCount: 0, amCompleted: false, pmCompleted: false)
        skinProfile = p ?? .empty
        irritationLogs = ir ?? []
        progressPhotos = ph ?? []
        isLoading = false

        routineConflicts = await service.detectRoutineConflicts(steps: routineSteps)
    }

    private func markRoutine(timeKey: String, completed: Bool) async {
        do {
            if completed {
                try await service.markCompleted(date: selectedDate, timeOfUse: timeKey)
            } else {
                try await service.markSkipped(date: selectedDate, timeOfUse: timeKey)
            }
            todayLogs = (try? await service.fetchHabitLogs(for: selectedDate)) ?? []
            streakInfo = (try? await service.computeStreak(for: selectedDate))
                ?? StreakInfo(currentStreak: 0, longestStreak: 0, weeklyCompletionCount: 0, amCompleted: false, pmCompleted: false)
        } catch {
            // keep optimistic state as-is; backend failure is non-critical here
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting types

private struct RoutineTip: Identifiable {
    let id: String
    let icon: String
    let message: String
}

// MARK: - Photo Picker Sheet

private struct PhotoPickerSheet: View {
    let service: HabitTrackerService
    var onUploaded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage? = nil
    @State private var showPicker = false
    @State private var notes = ""
    @State private var isUploading = false
    @State private var error: String?

    private let teal = Color(red: 0.30, green: 0.63, blue: 0.55)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.94, green: 0.98, blue: 0.97), Color(red: 0.88, green: 0.94, blue: 0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: 20) {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 20)
                    } else {
                        Button { showPicker = true } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill").font(.system(size: 36)).foregroundStyle(teal)
                                Text("Choose Photo").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(teal)
                            }
                            .frame(maxWidth: .infinity).frame(height: 180)
                            .background(RoundedRectangle(cornerRadius: 18).fill(teal.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(teal, lineWidth: 1.5).opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    if selectedImage != nil {
                        TextField("Optional notes...", text: $notes)
                            .font(.system(size: 15, design: .rounded))
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.88)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
                            .padding(.horizontal, 20)

                        Button {
                            Task { await upload() }
                        } label: {
                            Group {
                                if isUploading { ProgressView().tint(.white) }
                                else { Text("Save Photo").font(.system(size: 17, weight: .semibold, design: .rounded)) }
                            }
                            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 20).fill(teal))
                        }
                        .disabled(isUploading)
                        .padding(.horizontal, 20)
                    }

                    if let error { Text(error).font(.system(size: 13, design: .rounded)).foregroundStyle(.red).padding(.horizontal, 20) }
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Add Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(teal)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $selectedImage)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func upload() async {
        guard let img = selectedImage,
              let data = img.jpegData(compressionQuality: 0.82) else { return }
        isUploading = true
        error = nil
        do {
            _ = try await service.uploadProgressPhoto(imageData: data, notes: notes)
            onUploaded()
            dismiss()
        } catch {
            self.error = "Upload failed. Check your connection."
        }
        isUploading = false
    }
}

// MARK: - Image Picker Wrapper

private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
