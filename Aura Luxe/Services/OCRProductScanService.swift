import Foundation
import Supabase

final class OCRProductScanService {
    private let client = SupabaseManage.shared.client
    private let highlightDict = IngredientHighlightDictionary()
    private let conflictService = ConflictDetectionService()

    // MARK: - Public API

    func searchProduct(productName: String, brand: String?) async throws -> ScannedProductResult? {
        // Try to correct/confirm the brand using known brands from the DB.
        let correctedBrand: String?
        if let knownBrands = try? await fetchKnownBrands(), !knownBrands.isEmpty {
            let rawText = [brand, productName].compactMap { $0 }.joined(separator: " ")
            correctedBrand = detectBrand(in: rawText, from: knownBrands) ?? brand
        } else {
            correctedBrand = brand
        }

        let query = [correctedBrand, productName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nil }

        struct ProductRow: Decodable {
            let productName: String
            let brand: String?
            let ingredients: [String]
            let skinTypes: [String]
            let imageURL: String?
            let aliases: [String]
            enum CodingKeys: String, CodingKey {
                case productName = "product_name"
                case brand, ingredients
                case skinTypes   = "skin_types"
                case imageURL    = "image_url"
                case aliases
            }
        }

        let response = try await client
            .rpc("search_products_fuzzy", params: ["q": query])
            .execute()

        let rows = try JSONDecoder().decode([ProductRow].self, from: response.data)
        guard let row = rows.first else {
            return try await searchProductByKeywords(productName: productName, brand: correctedBrand)
        }

        let product = RecommendedProduct(
            name: row.productName,
            brand: row.brand,
            ingredients: row.ingredients,
            skinTypes: row.skinTypes,
            imageURL: row.imageURL,
            aliases: row.aliases
        )
        return try await enrich(product: product, scannedIngredients: row.ingredients)
    }

    private func searchProductByKeywords(productName: String, brand: String?) async throws -> ScannedProductResult? {
        let searchService = ProductSearchService()

        // Strategy 1: Search by brand (most distinctive signal), score candidates by name overlap.
        // Only use the result if at least one candidate has a positive word-overlap score;
        // a zero score means the brand search matched generically (e.g. "moisturizing cream")
        // and the first candidate would be an arbitrary wrong brand.
        search: do {
            guard let brand = brand, brand.count >= 3 else { break search }
            let candidates = try await searchService.search(query: brand, limit: 5)
            guard !candidates.isEmpty else { break search }
            let nameWords = productName.lowercased()
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 }
            let scored = candidates.map { product -> (RecommendedProduct, Int) in
                let score = nameWords.filter { product.name.lowercased().contains($0) }.count
                return (product, score)
            }
            let best = scored.max(by: { $0.1 < $1.1 }) ?? scored[0]
            guard best.1 > 0 else { break search }
            return try await enrich(product: best.0, scannedIngredients: best.0.ingredients)
        }

        // Strategy 2: Full product name string as a single query (no brand available, or
        // Strategy 1 found no confident match)
        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let results = try await searchService.search(query: trimmedName, limit: 1)
            if let product = results.first {
                return try await enrich(product: product, scannedIngredients: product.ingredients)
            }
        }

        return nil
    }

    func searchByIngredients(_ ingredients: [String]) async throws -> ScannedProductResult? {
        guard !ingredients.isEmpty else { return nil }

        let response = try await client
            .from("products")
            .select("product_name, brand, ingredients, skin_types, image_url, aliases")
            .overlaps("ingredients", value: ingredients)
            .limit(1)
            .execute()

        let products = try JSONDecoder().decode([RecommendedProduct].self, from: response.data)
        guard let product = products.first else {
            // No DB match — still build a highlights-only result from scanned ingredients
            return buildHighlightsOnly(ingredients: ingredients)
        }
        return try await enrich(product: product, scannedIngredients: ingredients)
    }

    // MARK: - Private

    private func enrich(product: RecommendedProduct, scannedIngredients: [String]) async throws -> ScannedProductResult {
        async let skinProfile = fetchUserSkinProfile()
        async let routineIngredients = fetchRoutineIngredients()

        let profile = try await skinProfile
        let routine = try await routineIngredients

        let compatibility = buildCompatibility(product: product, profile: profile)
        let highlights = highlightDict.highlights(for: product.ingredients.isEmpty ? scannedIngredients : product.ingredients)
        let conflicts = conflictService.detect(scannedIngredients: product.ingredients, routineIngredients: routine)

        return ScannedProductResult(
            product: product,
            matchedIngredients: scannedIngredients,
            ingredientHighlights: highlights,
            skinCompatibility: compatibility,
            conflicts: conflicts
        )
    }

    private func buildHighlightsOnly(ingredients: [String]) -> ScannedProductResult {
        let placeholder = RecommendedProduct(
            name: "Unidentified Product",
            brand: nil,
            ingredients: ingredients,
            skinTypes: ["all"],
            imageURL: nil,
            aliases: []
        )
        let highlights = highlightDict.highlights(for: ingredients)
        let compatibility = SkinCompatibility(isCompatible: true, userSkinTypes: [], productSkinTypes: ["all"], note: "")
        return ScannedProductResult(
            product: placeholder,
            matchedIngredients: ingredients,
            ingredientHighlights: highlights,
            skinCompatibility: compatibility,
            conflicts: []
        )
    }

    func fetchUserSkinProfile() async throws -> UserSkinProfile {
        let session = try await client.auth.session
        let userID = session.user.id

        struct QuizRow: Decodable {
            let skinAfterCleansing: String
            let oilinessDuringDay: String
            let sensitivityLevel: String
            enum CodingKeys: String, CodingKey {
                case skinAfterCleansing = "skin_after_cleansing"
                case oilinessDuringDay  = "oiliness_during_day"
                case sensitivityLevel   = "sensitivity_level"
            }
        }

        let response = try await client
            .from("onboarding_quiz_responses")
            .select("skin_after_cleansing, oiliness_during_day, sensitivity_level")
            .eq("user_id", value: userID.uuidString)
            .single()
            .execute()

        let row = try JSONDecoder().decode(QuizRow.self, from: response.data)

        var types: [String] = ["all"]
        let cleansing = row.skinAfterCleansing.lowercased()
        if cleansing.contains("tight") || cleansing.contains("dry") { types.append("dry") }
        if cleansing.contains("oily") { types.append("oily") }
        if row.oilinessDuringDay.lowercased().contains("often") { if !types.contains("oily") { types.append("oily") } }
        if row.sensitivityLevel.lowercased().contains("sensitive") { types.append("sensitive") }

        return UserSkinProfile(derivedSkinTypes: types)
    }

    func fetchRoutineIngredients() async throws -> [String] {
        let session = try await client.auth.session
        let userID = session.user.id

        struct RoutineRow: Decodable {
            let productName: String
            enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }

        let routineResponse = try await client
            .from("routine_steps")
            .select("product_name")
            .eq("user_id", value: userID.uuidString)
            .execute()

        let routineRows = try JSONDecoder().decode([RoutineRow].self, from: routineResponse.data)
        guard !routineRows.isEmpty else { return [] }

        let names = routineRows.map(\.productName)
        let productsResponse = try await client
            .from("products")
            .select("ingredients")
            .in("product_name", values: names)
            .execute()

        struct IngrRow: Decodable { let ingredients: [String] }
        let ingrRows = try JSONDecoder().decode([IngrRow].self, from: productsResponse.data)
        return ingrRows.flatMap(\.ingredients)
    }

    private func fetchKnownBrands() async throws -> [String] {
        struct BrandRow: Decodable {
            let brand: String?
        }
        let response = try await client
            .from("products")
            .select("brand")
            .execute()
        let rows = try JSONDecoder().decode([BrandRow].self, from: response.data)
        return Array(Set(rows.compactMap(\.brand).filter { !$0.isEmpty }))
    }

    private func detectBrand(in rawText: String, from brands: [String]) -> String? {
        let lower = rawText.lowercased()
        // Sort longest first so "La Roche-Posay" matches before "La"
        return brands
            .sorted { $0.count > $1.count }
            .first { lower.contains($0.lowercased()) }
    }

    private func buildCompatibility(product: RecommendedProduct, profile: UserSkinProfile) -> SkinCompatibility {
        let userTypes = profile.derivedSkinTypes
        let productTypes = product.skinTypes
        let isCompatible = productTypes.contains("all") || productTypes.contains { userTypes.contains($0) }
        let userLabel = userTypes.filter { $0 != "all" }.map { $0.capitalized }.joined(separator: "/")
        let note: String
        if isCompatible {
            note = userLabel.isEmpty ? "Suitable for your skin type" : "Works well for \(userLabel) skin"
        } else {
            let productLabel = productTypes.filter { $0 != "all" }.map { $0.capitalized }.joined(separator: "/")
            note = "Formulated for \(productLabel) skin — may not suit your \(userLabel) skin"
        }
        return SkinCompatibility(isCompatible: isCompatible, userSkinTypes: userTypes, productSkinTypes: productTypes, note: note)
    }
}
