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
    let suitableSkinTypes: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case ingredients
        case suitableSkinTypes = "suitable_skin_types"
    }
}
