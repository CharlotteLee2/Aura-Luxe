import SwiftUI

struct CompareProductsView: View {
    let productA: ScannedProductResult
    let productB: ScannedProductResult

    @Environment(\.dismiss) private var dismiss
    @State private var crossConflicts: [IngredientConflict] = []

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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        columnHeaders
                        imagesRow
                        compatibilityRow
                        highlightsRow
                        conflictsRow
                        if !crossConflicts.isEmpty {
                            crossConflictsSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
            }
        }
        .onAppear {
            crossConflicts = ConflictDetectionService().detect(
                ingredientsA: productA.product.ingredients,
                ingredientsB: productB.product.ingredients
            )
        }
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let brand = productA.product.brand {
                    Text(brand)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
                Text(productA.product.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 50)

            VStack(alignment: .leading, spacing: 2) {
                if let brand = productB.product.brand {
                    Text(brand)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
                Text(productB.product.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    // MARK: - Images Row

    private var imagesRow: some View {
        CompareCard(label: "Product") {
            HStack(spacing: 10) {
                productThumb(product: productA.product)
                Divider().frame(height: 90)
                productThumb(product: productB.product)
            }
        }
    }

    private func productThumb(product: RecommendedProduct) -> some View {
        Group {
            if let urlStr = product.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { imagePlaceholder }
            } else {
                imagePlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.92, green: 0.97, blue: 0.96))
            .overlay(Image(systemName: "drop.fill").font(.system(size: 24)).foregroundStyle(Color(red: 0.72, green: 0.82, blue: 0.82)))
    }

    // MARK: - Compatibility Row

    private var compatibilityRow: some View {
        CompareCard(label: "Skin Compatibility") {
            HStack(alignment: .top, spacing: 10) {
                compatibilityColumn(productA.skinCompatibility)
                Divider()
                compatibilityColumn(productB.skinCompatibility)
            }
        }
    }

    private func compatibilityColumn(_ compat: SkinCompatibility) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: compat.isCompatible ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(compat.isCompatible ? Color(red: 0.20, green: 0.65, blue: 0.45) : Color(red: 0.80, green: 0.50, blue: 0.10))
                Text(compat.isCompatible ? "Compatible" : "Review")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(compat.isCompatible ? Color(red: 0.20, green: 0.65, blue: 0.45) : Color(red: 0.80, green: 0.50, blue: 0.10))
            }
            Text(compat.note)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Highlights Row

    private var highlightsRow: some View {
        let allKeywordsA = Set(productA.ingredientHighlights.map(\.keyword))
        let allKeywordsB = Set(productB.ingredientHighlights.map(\.keyword))

        return CompareCard(label: "Key Ingredients") {
            HStack(alignment: .top, spacing: 10) {
                highlightsColumn(productA.ingredientHighlights, uniqueKeywords: allKeywordsA.subtracting(allKeywordsB))
                Divider()
                highlightsColumn(productB.ingredientHighlights, uniqueKeywords: allKeywordsB.subtracting(allKeywordsA))
            }
        }
    }

    private func highlightsColumn(_ highlights: [IngredientHighlight], uniqueKeywords: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if highlights.isEmpty {
                Text("None detected")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            } else {
                ForEach(highlights, id: \.keyword) { h in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(uniqueKeywords.contains(h.keyword) ? Color(red: 0.20, green: 0.65, blue: 0.45) : Color(red: 0.72, green: 0.82, blue: 0.82))
                            .frame(width: 6, height: 6)
                        Text(h.label)
                            .font(.system(size: 12, weight: uniqueKeywords.contains(h.keyword) ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Conflicts Row

    private var conflictsRow: some View {
        CompareCard(label: "Routine Conflicts") {
            HStack(alignment: .top, spacing: 10) {
                conflictsColumn(productA.conflicts)
                Divider()
                conflictsColumn(productB.conflicts)
            }
        }
    }

    private func conflictsColumn(_ conflicts: [IngredientConflict]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if conflicts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color(red: 0.20, green: 0.65, blue: 0.45))
                    Text("No conflicts").font(.system(size: 12, design: .rounded)).foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
            } else {
                ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 0.85, green: 0.55, blue: 0.10))
                        Text("\(conflict.ingredientA) + \(conflict.ingredientB)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cross Conflicts

    private var crossConflictsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.orange)
                Text("Conflicts Between These Products")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            VStack(spacing: 8) {
                ForEach(Array(crossConflicts.enumerated()), id: \.offset) { _, conflict in
                    ConflictRowView(conflict: conflict)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }
}

private struct CompareCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                .textCase(.uppercase)
                .tracking(0.5)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
    }
}
