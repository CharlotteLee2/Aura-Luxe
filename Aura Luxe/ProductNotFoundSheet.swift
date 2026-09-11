import SwiftUI

struct ProductNotFoundSheet: View {
    let ocrName: String
    let ocrBrand: String
    let ocrIngredients: [String]
    let capturedImage: UIImage
    var onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAddProduct = false

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
                    Spacer()

                    VStack(spacing: 20) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.90, green: 0.97, blue: 0.96))
                                .frame(width: 72, height: 72)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                        }

                        // Message
                        VStack(spacing: 8) {
                            Text("Couldn't find this product")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                                .multilineTextAlignment(.center)

                            Text("Would you like to add it to your list?")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                                .multilineTextAlignment(.center)
                        }

                        // OCR preview (if we got any name/brand)
                        if !ocrName.isEmpty || !ocrBrand.isEmpty {
                            HStack(spacing: 10) {
                                Image(uiImage: capturedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    if !ocrBrand.isEmpty {
                                        Text(ocrBrand)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                                    }
                                    Text(ocrName.isEmpty ? "Unknown Product" : ocrName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.84))
                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color(red: 0.78, green: 0.88, blue: 0.88), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer()

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            showAddProduct = true
                        } label: {
                            Text("Add Product")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.30, green: 0.63, blue: 0.55)))
                        }

                        Button {
                            dismiss()
                            onRetry()
                        } label: {
                            Text("Retry Scan")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color(red: 0.30, green: 0.63, blue: 0.55), lineWidth: 1.5)
                                )
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddProduct) {
            AddUnknownProductView(
                prefilledIngredients: ocrIngredients,
                prefilledName: ocrName,
                prefilledBrand: ocrBrand,
                capturedImage: capturedImage
            )
        }
    }
}
