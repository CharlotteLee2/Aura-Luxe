import SwiftUI
import UIKit

struct CameraPageView: View {
    @State private var scanMode: ScanMode = .product
    @State private var triggerCapture = false
    @State private var isProcessing = false
    @State private var scanResult: ScannedProductResult?
    @State private var showResultSheet = false
    @State private var compareFirstResult: ScannedProductResult?
    @State private var compareBothResults: (ScannedProductResult, ScannedProductResult)?
    @State private var showCompareView = false
    @State private var ocrIngredients: [String] = []
    @State private var capturedImage: UIImage?
    @State private var ocrBrand: String = ""
    @State private var ocrName: String = ""
    @State private var showNotFoundSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraView(triggerCapture: $triggerCapture, onCapture: handleCapture)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 12)

                if compareFirstResult == nil {
                    scanModePill
                        .padding(.top, 12)
                }

                Spacer()

                ViewfinderBracket()

                Spacer()

                helperText
                    .padding(.bottom, 16)

                shutterRow
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)

            if isProcessing {
                processingOverlay
            }
        }
        .sheet(isPresented: $showResultSheet) {
            if let result = scanResult {
                ScanResultSheet(result: result, onCompare: {
                    compareFirstResult = result
                })
            }
        }
        .fullScreenCover(isPresented: $showCompareView, onDismiss: {
            compareBothResults = nil
        }) {
            if let (a, b) = compareBothResults {
                CompareProductsView(productA: a, productB: b)
            }
        }
        .sheet(isPresented: $showNotFoundSheet) {
            if let img = capturedImage {
                ProductNotFoundSheet(
                    ocrName: ocrName,
                    ocrBrand: ocrBrand,
                    ocrIngredients: ocrIngredients,
                    capturedImage: img,
                    onRetry: {}
                )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(compareFirstResult == nil ? "Scan" : "Scan 2nd Product")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if compareFirstResult != nil {
                Button {
                    compareFirstResult = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Scan Mode Pill

    private var scanModePill: some View {
        HStack(spacing: 0) {
            scanModeButton("Product", mode: .product)
            scanModeButton("Ingredients", mode: .ingredients)
        }
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    private func scanModeButton(_ label: String, mode: ScanMode) -> some View {
        let isSelected = scanMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { scanMode = mode }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color(red: 0.14, green: 0.20, blue: 0.20) : .white.opacity(0.7))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Capsule().fill(.white)
                        : nil
                )
                .padding(3)
        }
    }

    // MARK: - Viewfinder

    private var helperText: some View {
        Group {
            if compareFirstResult != nil {
                Text("Point at the second product to compare")
            } else if scanMode == .product {
                Text("Point at the product's front label")
            } else {
                Text("Point at the ingredient list")
            }
        }
        .font(.system(size: 14, design: .rounded))
        .foregroundStyle(.white.opacity(0.8))
        .multilineTextAlignment(.center)
    }

    // MARK: - Shutter

    private var shutterRow: some View {
        HStack {
            Spacer()
            Button {
                guard !isProcessing else { return }
                triggerCapture = true
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color(red: 0.30, green: 0.63, blue: 0.55), lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }
            Spacer()
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Analyzing...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Capture Handler

    private func handleCapture(_ image: UIImage) {
        isProcessing = true
        capturedImage = image
        Task {
            do {
                let service = OCRProductScanService()
                var result: ScannedProductResult?
                var extractedBrand = ""
                var extractedName = ""
                var extractedIngredients: [String] = []

                if scanMode == .product {
                    let observations = await OCRScan.shared.recognizeTextWithBounds(from: image)
                    let (brand, name) = ProductModeParser().parse(observations: observations)
                    extractedBrand = brand ?? ""
                    extractedName = name
                    result = try await service.searchProduct(productName: name, brand: brand)
                } else {
                    let lines = await OCRScan.shared.recognizeText(from: image)
                    let ingredients = IngredientModeParser().parse(lines: lines)
                    extractedIngredients = ingredients
                    result = try await service.searchByIngredients(ingredients)
                    // No ingredient list found — fall back to product-name search using
                    // the same extraction path as product mode.
                    if ingredients.isEmpty {
                        let observations = await OCRScan.shared.recognizeTextWithBounds(from: image)
                        let (brand, name) = ProductModeParser().parse(observations: observations)
                        extractedBrand = brand ?? ""
                        extractedName = name
                        result = try await service.searchProduct(productName: name, brand: brand)
                    }
                }

                await MainActor.run {
                    isProcessing = false
                    ocrBrand = extractedBrand
                    ocrName = extractedName
                    ocrIngredients = extractedIngredients

                    guard let result else {
                        showNotFoundSheet = true
                        return
                    }

                    if let first = compareFirstResult {
                        compareBothResults = (first, result)
                        compareFirstResult = nil
                        showCompareView = true
                    } else {
                        scanResult = result
                        showResultSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showNotFoundSheet = true
                }
            }
        }
    }
}

// MARK: - Viewfinder Bracket

private struct ViewfinderBracket: View {
    private let size: CGFloat = 240
    private let cornerLength: CGFloat = 26
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                .frame(width: size, height: size)

            ForEach(0..<4, id: \.self) { corner in
                cornerBracket(corner: corner)
            }
        }
        .frame(width: size, height: size)
    }

    // Path coordinate origin is top-left of the frame (0,0)
    private func cornerBracket(corner: Int) -> some View {
        let s = size
        let L = cornerLength
        // corner order: 0=top-left, 1=top-right, 2=bottom-right, 3=bottom-left
        let corners: [(CGFloat, CGFloat)] = [(0, 0), (s, 0), (s, s), (0, s)]
        let (cx, cy) = corners[corner]
        let hDir: CGFloat = (corner == 0 || corner == 3) ? 1 : -1
        let vDir: CGFloat = (corner == 0 || corner == 1) ? 1 : -1

        return Path { path in
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx + hDir * L, y: cy))
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy + vDir * L))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .frame(width: s, height: s)
    }
}
