import SwiftUI

struct ScanResultSheet: View {
    let result: ScannedProductResult
    var onCompare: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSheet = false
    @State private var showTimePickerSheet = false
    @State private var showIngredientsSheet = false
    @State private var selectedTime: TimeOfUseOption = .both
    @State private var isAddingToRoutine = false
    @State private var addedToRoutine = false
    @State private var routineError: String?

    private let routineService = SkincareRoutineService()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    productHeader
                    Divider().padding(.horizontal, 20).padding(.vertical, 4)
                    if !result.skinCompatibility.note.isEmpty {
                        compatibilitySection
                    }
                    if !result.ingredientHighlights.isEmpty {
                        highlightsSection
                    }
                    if !result.conflicts.isEmpty {
                        conflictsSection
                    }
                    actionButtons
                        .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSaveSheet) {
            SaveToBoardSheet(productName: result.product.name)
        }
        .sheet(isPresented: $showTimePickerSheet) {
            RoutineTimePickerSheet(selectedTime: $selectedTime) {
                Task { await addToRoutine() }
            }
        }
        .sheet(isPresented: $showIngredientsSheet) {
            IngredientsListSheet(ingredients: result.product.ingredients)
        }
    }

    // MARK: - Header

    private var productHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            productImage
            VStack(alignment: .leading, spacing: 4) {
                if let brand = result.product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
                Text(result.product.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                    .fixedSize(horizontal: false, vertical: true)
                compatibilityBadge
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var productImage: some View {
        Group {
            if let urlString = result.product.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    productImagePlaceholder
                }
            } else {
                productImagePlaceholder
            }
        }
        .frame(width: 80, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1)
        )
    }

    private var productImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.92, green: 0.97, blue: 0.96))
            .overlay(
                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.72, green: 0.82, blue: 0.82))
            )
    }

    private var compatibilityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.skinCompatibility.isCompatible ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(result.skinCompatibility.isCompatible ? "Compatible" : "Review Needed")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(result.skinCompatibility.isCompatible ? Color(red: 0.20, green: 0.65, blue: 0.45) : Color(red: 0.80, green: 0.50, blue: 0.10))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                result.skinCompatibility.isCompatible
                    ? Color(red: 0.90, green: 0.97, blue: 0.93)
                    : Color(red: 0.99, green: 0.94, blue: 0.88)
            )
        )
        .padding(.top, 2)
    }

    // MARK: - Compatibility Section

    private var compatibilitySection: some View {
        ScanSectionCard(title: "Skin Compatibility") {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.skinCompatibility.note)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                if !result.skinCompatibility.userSkinTypes.filter({ $0 != "all" }).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(result.skinCompatibility.userSkinTypes.filter { $0 != "all" }, id: \.self) { type in
                            Text(type.capitalized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.34, green: 0.53, blue: 0.52))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(red: 0.90, green: 0.97, blue: 0.96)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Highlights Section

    private var highlightsSection: some View {
        ScanSectionCard(title: "Key Ingredients") {
            VStack(spacing: 10) {
                ForEach(result.ingredientHighlights, id: \.keyword) { highlight in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(sentimentColor(highlight.sentiment))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(highlight.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            Text(highlight.description)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Conflicts Section

    private var conflictsSection: some View {
        ScanSectionCard(title: "Routine Conflicts", titleIcon: "exclamationmark.triangle.fill", titleIconColor: .orange) {
            VStack(spacing: 8) {
                ForEach(Array(result.conflicts.enumerated()), id: \.offset) { _, conflict in
                    ConflictRowView(conflict: conflict)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if addedToRoutine {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Added to Routine")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.20, green: 0.65, blue: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.90, green: 0.97, blue: 0.93)))
                .padding(.horizontal, 20)
            } else {
                Button {
                    showTimePickerSheet = true
                } label: {
                    HStack(spacing: 6) {
                        if isAddingToRoutine { ProgressView().tint(.white) }
                        Text("Add to Routine")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.30, green: 0.63, blue: 0.55)))
                }
                .disabled(isAddingToRoutine)
                .padding(.horizontal, 20)
            }

            Button {
                showSaveSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                    Text("Like / Save")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(red: 0.30, green: 0.63, blue: 0.55), lineWidth: 1.5)
                )
            }
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                Button {
                    showIngredientsSheet = true
                } label: {
                    Text("View Ingredients")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Divider().frame(height: 20)

                Button {
                    dismiss()
                    onCompare()
                } label: {
                    Text("Compare")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private func sentimentColor(_ sentiment: HighlightSentiment) -> Color {
        switch sentiment {
        case .beneficial: return Color(red: 0.20, green: 0.65, blue: 0.45)
        case .caution:    return Color(red: 0.85, green: 0.60, blue: 0.10)
        case .warning:    return Color(red: 0.85, green: 0.30, blue: 0.25)
        }
    }

    private func addToRoutine() async {
        isAddingToRoutine = true
        do {
            let userID = try await routineService.authenticatedUserID()
            let entry = SkincareRoutineEntry(user_id: userID, product_name: result.product.name, time_of_use: selectedTime.rawValue)
            try await routineService.save(entries: [entry])
            withAnimation { addedToRoutine = true }
        } catch {
            routineError = "Couldn't add to routine. Please try again."
        }
        isAddingToRoutine = false
    }
}

// MARK: - Supporting Views

private enum TimeOfUseOption: String, CaseIterable {
    case morning, night, both
    var label: String {
        switch self { case .morning: "Morning"; case .night: "Night"; case .both: "Both" }
    }
}

private struct RoutineTimePickerSheet: View {
    @Binding var selectedTime: TimeOfUseOption
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When will you use this?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))

                HStack(spacing: 0) {
                    ForEach(TimeOfUseOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTime = option }
                        } label: {
                            Text(option.label)
                                .font(.system(size: 15, weight: selectedTime == option ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(
                                    selectedTime == option
                                        ? Color(red: 0.34, green: 0.53, blue: 0.52)
                                        : Color(red: 0.39, green: 0.48, blue: 0.48)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTime == option
                                        ? RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95))
                                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                        : nil
                                )
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.6)))
                .padding(.horizontal, 24)

                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Text("Add to Routine")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.30, green: 0.63, blue: 0.55)))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 32)
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
            }
        }
    }
}

private struct IngredientsListSheet: View {
    let ingredients: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ingredient in
                        Text(ingredient)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                        Divider().padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("All Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct ScanSectionCard<Content: View>: View {
    let title: String
    var titleIcon: String? = nil
    var titleIconColor: Color = Color(red: 0.30, green: 0.63, blue: 0.55)
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                if let icon = titleIcon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(titleIconColor)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.84))
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

struct ConflictRowView: View {
    let conflict: IngredientConflict

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: conflict.severity == .avoid ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(conflict.severity == .avoid ? Color(red: 0.85, green: 0.30, blue: 0.25) : Color(red: 0.85, green: 0.55, blue: 0.10))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(conflict.ingredientA) + \(conflict.ingredientB)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                Text(conflict.message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(conflict.severity == .avoid ? Color(red: 0.99, green: 0.93, blue: 0.92) : Color(red: 0.99, green: 0.96, blue: 0.88))
        )
    }
}
