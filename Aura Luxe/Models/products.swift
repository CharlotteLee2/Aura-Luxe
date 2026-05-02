//
//  products.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 1/7/26.
//

import Foundation

struct products: Codable {
    let name: String
    let ingredients: [String]
    let skinTypes: [String]
    let brand: String?
    let aliases: [String]
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case name       = "product_name"
        case ingredients
        case skinTypes  = "skin_types"
        case brand
        case aliases
        case imageURL   = "image_url"
    }
}
