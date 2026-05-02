import Foundation

struct RecommendedProduct: Identifiable, Codable, Equatable {
    let name: String
    let brand: String?
    let ingredients: [String]
    let skinTypes: [String]
    let imageURL: String?
    let aliases: [String]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name        = "product_name"
        case brand
        case ingredients
        case skinTypes   = "skin_types"
        case imageURL    = "image_url"
        case aliases
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name        = try c.decode(String.self, forKey: .name)
        brand       = try c.decodeIfPresent(String.self, forKey: .brand)
        ingredients = try c.decode([String].self, forKey: .ingredients)
        skinTypes   = try c.decode([String].self, forKey: .skinTypes)
        imageURL    = try c.decodeIfPresent(String.self, forKey: .imageURL)
        aliases     = (try? c.decode([String].self, forKey: .aliases)) ?? []
    }

    init(name: String, brand: String? = nil, ingredients: [String], skinTypes: [String], imageURL: String? = nil, aliases: [String] = []) {
        self.name        = name
        self.brand       = brand
        self.ingredients = ingredients
        self.skinTypes   = skinTypes
        self.imageURL    = imageURL
        self.aliases     = aliases
    }
}
