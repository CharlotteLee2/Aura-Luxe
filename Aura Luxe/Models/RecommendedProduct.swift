import Foundation

struct RecommendedProduct: Identifiable, Codable, Equatable {
    let name: String
    let ingredients: [String]
    let skinTypes: [String]
    let imageURL: String?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name        = "product_name"
        case ingredients
        case skinTypes   = "skin_types"
        case imageURL    = "image_url"
    }
}
