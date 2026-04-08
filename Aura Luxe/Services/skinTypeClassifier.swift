//
//  skinTypeClassifier.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 1/7/26.
//

import Foundation

final class skinTypeClassifier {

    struct Rule {
        let keyword: String
        let types: [String]
    }

    private let rules: [Rule] = [
        Rule(keyword: "salicylic", types: ["oily"]),
        Rule(keyword: "benzoyl", types: ["oily"]),
        Rule(keyword: "niacinamide", types: ["all"]),
        Rule(keyword: "hyaluronic", types: ["dry"]),
        Rule(keyword: "glycerin", types: ["dry"]),
        Rule(keyword: "ceramide", types: ["all"]),
        Rule(keyword: "squalane", types: ["all"]),
        Rule(keyword: "retinol", types: ["all"]),
        Rule(keyword: "alpha hydroxy", types: ["oily", "sensitive"]),
        Rule(keyword: "aha", types: ["oily", "sensitive"]),
        Rule(keyword: "glycolic", types: ["oily", "sensitive"]),
        Rule(keyword: "lactic", types: ["oily", "sensitive"]),
        Rule(keyword: "alcohol", types: ["sensitive"]),
        Rule(keyword: "fragrance", types: ["sensitive"]),
        Rule(keyword: "parfum", types: ["sensitive"]),
        Rule(keyword: "panthenol", types: ["all", "sensitive"]),
        Rule(keyword: "provitamin b5", types: ["all", "sensitive"])
    ]

    func classify(from ingredients: [String]) -> [String] {
        var matchedTypes = Set<String>()

        let lowercasedIngredients = ingredients.map { $0.lowercased() }

        for ingredient in lowercasedIngredients {
            for rule in rules where ingredient.contains(rule.keyword) {
                rule.types.forEach { matchedTypes.insert($0) }
            }
        }

        // If nothing matched, default to "all"
        return matchedTypes.isEmpty ? ["all"] : Array(matchedTypes)
    }
}
