import SwiftUI
import Supabase

struct AddUnknownProductView: View {
    let prefilledIngredients: [String]
    let prefilledName: String
    let prefilledBrand: String
    let capturedImage: UIImage?

    @Environment(\.dismiss) private var dismiss
    @State private var productName: String
    @State private var brandName: String
    @State private var ingredients: [String]
    @State private var selectedSkinTypes: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let repository = productRepository()
    private let likedService = LikedProductsService()
    private let client = SupabaseManage.shared.client
    private let skinTypes = ["Oily", "Dry", "Sensitive", "Combination", "All"]

    init(
        prefilledIngredients: [String] = [],
        prefilledName: String = "",
        prefilledBrand: String = "",
        capturedImage: UIImage? = nil
    ) {
        self.prefilledIngredients = prefilledIngredients
        self.prefilledName = prefilledName
        self.prefilledBrand = prefilledBrand
        self.capturedImage = capturedImage
        _productName = State(initialValue: prefilledName)
        _brandName = State(initialValue: prefilledBrand)
        _ingredients = State(initialValue: prefilledIngredients)
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerSection
                        if let img = capturedImage { photoThumbnail(img) }
                        productDetailsSection
                        ingredientsSection
                        skinTypesSection
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.25))
                                .padding(.horizontal, 20)
                        }
                        saveButton
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private func photoThumbnail(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan photo")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("Will be saved with this product")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Product not found")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            Text("Add it to the database so you and others can find it next time.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var productDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Product Details")
            VStack(spacing: 10) {
                styledTextField(title: "Product Name", text: $productName, placeholder: "e.g. Moisturizing Cream")
                styledTextField(title: "Brand", text: $brandName, placeholder: "e.g. CeraVe")
            }
        }
        .padding(.horizontal, 20)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Detected Ingredients")
                Spacer()
                Text("\(ingredients.count) found")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            }
            VStack(alignment: .leading, spacing: 6) {
                let preview = ingredients.prefix(8).joined(separator: ", ")
                let overflow = ingredients.count > 8 ? " + \(ingredients.count - 8) more" : ""
                Text(preview + overflow)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.84)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    private var skinTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Skin Type (optional)")
            FlowLayout(spacing: 8) {
                ForEach(skinTypes, id: \.self) { type in
                    let selected = selectedSkinTypes.contains(type)
                    Button {
                        if selected { selectedSkinTypes.remove(type) } else { selectedSkinTypes.insert(type) }
                    } label: {
                        Text(type)
                            .font(.system(size: 14, weight: selected ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selected ? .white : Color(red: 0.34, green: 0.53, blue: 0.52))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected ? Color(red: 0.30, green: 0.63, blue: 0.55) : Color.white.opacity(0.84))
                            )
                            .overlay(
                                Capsule().strokeBorder(Color(red: 0.30, green: 0.63, blue: 0.55), lineWidth: selected ? 0 : 1.5)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 6) {
                if isSaving { ProgressView().tint(.white) }
                Text(showSuccess ? "Saved!" : "Save Product")
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(showSuccess ? Color(red: 0.20, green: 0.65, blue: 0.45) : Color(red: 0.30, green: 0.63, blue: 0.55))
            )
        }
        .disabled(isSaving || productName.trimmingCharacters(in: .whitespaces).isEmpty)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func styledTextField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1))
        }
    }

    private func save() async {
        let trimmedName = productName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        errorMessage = nil
        isSaving = true

        do {
            // Upload photo to Supabase Storage if available
            var uploadedImageURL: String? = nil
            if let img = capturedImage, let jpegData = img.jpegData(compressionQuality: 0.8) {
                let path = "\(UUID().uuidString).jpg"
                try await client.storage
                    .from("product-images")
                    .upload(path, data: jpegData, options: .init(contentType: "image/jpeg"))
                uploadedImageURL = try client.storage
                    .from("product-images")
                    .getPublicURL(path: path)
                    .absoluteString
            }

            let skinTypeValues = selectedSkinTypes.isEmpty ? ["all"] : selectedSkinTypes.map { $0.lowercased() }
            let product = products(
                name: trimmedName,
                ingredients: ingredients,
                skinTypes: skinTypeValues,
                brand: brandName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brandName.trimmingCharacters(in: .whitespaces),
                aliases: [],
                imageURL: uploadedImageURL
            )

            try await repository.save(product)
            // Auto-like so the product appears in the user's My Products page
            try await likedService.like(productName: trimmedName)

            withAnimation { showSuccess = true }
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            errorMessage = "Couldn't save the product. Please try again."
        }
        isSaving = false
    }
}

// Simple flow layout for skin type chips
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > width, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
