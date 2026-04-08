//
//  INCIDecoderScraper.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 1/7/26.
//

import Foundation
import SwiftSoup

final class INCIDecoderScraper {

    func scrapeIngredient(from urlString: String) async throws -> String {
        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let doc = try SwiftSoup.parse(html)

        // INCI Decoder ingredient name is the H1
        let ingredientName = try doc
            .select("h1")
            .first()?
            .text() ?? "Unknown Ingredient"

        return ingredientName
    }
}
