//
//  ProductsViewModel.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 1/7/26.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class ProductsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let scraper = INCIDecoderScraper()
    private let classifier = skinTypeClassifier()
    private let repository = productRepository()

    func runStartupScrape() async {

        // ✅ SIMPLE GUARD — GOES HERE
        if UserDefaults.standard.bool(forKey: "didScrapeOnce") {
            print("⏭️ Startup scrape already completed — skipping")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let ingredientURL =
                "https://incidecoder.com/ingredients/niacinamide"

            let ingredient = try await scraper.scrapeIngredient(
                from: ingredientURL
            )

            let ingredients = [ingredient]

            let skinTypes = classifier.classify(from: ingredients)

            let product = products(
                name: ingredient,
                ingredients: ingredients,
                skinTypes: skinTypes,
                brand: nil,
                aliases: []
            )

            try await repository.save(product)

            // ✅ MARK AS DONE ONLY AFTER SUCCESS
            UserDefaults.standard.set(true, forKey: "didScrapeOnce")

            print("✅ Startup scrape completed")

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Startup scrape failed:", error)
        }
    }
}
