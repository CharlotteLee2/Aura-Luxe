import Foundation

enum ScanMode { case product, ingredients }

struct ScannedProductResult: Identifiable, Equatable {
    let product: RecommendedProduct
    let matchedIngredients: [String]
    let ingredientHighlights: [IngredientHighlight]
    let skinCompatibility: SkinCompatibility
    let conflicts: [IngredientConflict]

    var id: String { product.name }

    static func == (lhs: ScannedProductResult, rhs: ScannedProductResult) -> Bool {
        lhs.product == rhs.product
    }
}

struct SkinCompatibility {
    let isCompatible: Bool
    let userSkinTypes: [String]
    let productSkinTypes: [String]
    let note: String
}

struct UserSkinProfile {
    let derivedSkinTypes: [String]
}
