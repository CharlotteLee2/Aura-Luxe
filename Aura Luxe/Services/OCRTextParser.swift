import Foundation
import CoreGraphics

// Strips noise and marketing language from a single OCR text observation.
func preprocessOCRLine(_ raw: String) -> String {
    var text = raw

    // Remove special decoration characters
    let specialChars: [Character] = ["|", "•", "·", "*", "–", "—"]
    text = String(text.filter { !specialChars.contains($0) })

    // Strip marketing phrases (case-insensitive)
    let marketingPhrases = [
        "clinically tested", "dermatologist tested", "dermatologist recommended",
        "clinically proven", "hypoallergenic", "non-comedogenic",
        "fragrance-free", "fragrance free", "paraben-free", "paraben free",
        "#1 dermatologist", "#1 brand", "trusted by", "new formula",
        "advanced formula", "gentle enough", "for all skin", "suitable for",
        "clinically", "dermatologist", "ophthalmologist tested",
        "allergy tested", "non-irritating", "skin-tested"
    ]
    let lower = text.lowercased()
    for phrase in marketingPhrases where lower.contains(phrase) {
        text = text.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
    }

    // Collapse multiple spaces and trim
    while text.contains("  ") {
        text = text.replacingOccurrences(of: "  ", with: " ")
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct ProductModeParser {
    private let noisePatterns = ["www.", ".com", "net wt", "fl oz", "made in", " lot ", "exp ", "mfg ", "distributed", "manufactured", "©", "®", "™"]
    private let terminators = ["directions", "how to use", "warnings", "caution", "net wt", "www.", "distributed by", "manufactured"]

    func parse(observations: [(text: String, rect: CGRect)]) -> (brand: String?, productName: String) {
        // Vision uses bottom-left origin; sort top-to-bottom by descending minY
        let sorted = observations
            .map { (text: preprocessOCRLine($0.text), rect: $0.rect) }
            .filter { isValidLine($0.text) }
            .sorted { $0.rect.minY > $1.rect.minY }

        guard !sorted.isEmpty else { return (nil, "") }

        let scored = sorted.map { obs -> (text: String, rect: CGRect, score: Int) in
            var score = 0
            let text = obs.text
            let upper = text.uppercased()
            if text == upper && text.count >= 4 { score += 3 }
            if obs.rect.height > 0.06 { score += 2 }
            if text.rangeOfCharacter(from: .decimalDigits) == nil { score += 1 }
            if obs.rect.minY > 0.6 { score += 1 }  // top 40% of image (minY > 0.6 in bottom-left coords)
            return (text, obs.rect, score)
        }

        let rankSorted = scored.sorted { $0.score > $1.score }
        // Highest-scored text is usually the product descriptor (e.g. "MOISTURIZING CREAM" in ALL CAPS).
        // Second-ranked is usually the brand name (e.g. "CeraVe" in mixed case).
        let productNameRaw = rankSorted.first?.text
        let brandRaw = rankSorted.count > 1 ? rankSorted[1].text : rankSorted.first?.text

        return (
            brand: brandRaw.map(clean),
            productName: productNameRaw.map(clean) ?? ""
        )
    }

    private func isValidLine(_ text: String) -> Bool {
        guard text.count >= 3 else { return false }
        let lower = text.lowercased()
        return !noisePatterns.contains { lower.contains($0) }
    }

    private func clean(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "™", with: "")
        result = result.replacingOccurrences(of: "®", with: "")
        result = result.replacingOccurrences(of: "©", with: "")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > 60 { result = String(result.prefix(60)) }
        return result
    }
}

struct IngredientModeParser {
    private let startMarkers = [
        "ingredients:", "ingredients", "ingr.", "inci:", "active ingredients:",
        "ingredient:", "ingrédients:", "ingrdients:", "ingrediants:"
    ]
    private let terminators = ["directions", "how to use", "warnings", "caution:", "net wt", "www.", "distributed by", "manufactured"]

    private func cleanIngredientToken(_ raw: String) -> String {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Strip trailing percentage amounts (e.g. "dimethicone 1.0%" → "dimethicone")
        token = token.replacingOccurrences(of: #"\s*\d+\.?\d*\s*%"#, with: "",
                                           options: .regularExpression)
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parse(lines: [String]) -> [String] {
        var startIndex = 0
        var ingredientText = ""

        // Find the ingredient list start
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if let marker = startMarkers.first(where: { lower.contains($0) }) {
                // Extract text after the marker on the same line
                if let range = lower.range(of: marker) {
                    let remainder = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remainder.isEmpty { ingredientText = remainder + ", " }
                }
                startIndex = i + 1
                break
            }
        }

        // Collect lines until a terminator
        for line in lines[startIndex...] {
            let lower = line.lowercased()
            if terminators.contains(where: { lower.hasPrefix($0) }) { break }
            ingredientText += line + ", "
        }

        // No marker found — attempt to treat the entire text as a no-header ingredient list.
        // Signal: at least 3 comma-separated letter-containing tokens across all lines.
        if startIndex == 0 && ingredientText.isEmpty {
            let allText = lines.joined(separator: ", ")
            let candidateTokens = allText
                .components(separatedBy: ",")
                .map { cleanIngredientToken($0) }
                .filter { token in
                    guard token.count >= 2 else { return false }
                    guard token.rangeOfCharacter(from: .letters) != nil else { return false }
                    let skip = ["and", "may contain", "ci ", "contains", "www", ".com"]
                    return !skip.contains(where: { token.hasPrefix($0) })
                }
            if candidateTokens.count >= 3 {
                return candidateTokens
            }
            return []
        }

        // Split and clean
        return ingredientText
            .components(separatedBy: ",")
            .map { cleanIngredientToken($0) }
            .filter { token in
                guard token.count >= 2 else { return false }
                guard token.rangeOfCharacter(from: .letters) != nil else { return false }
                let skip = ["and", "may contain", "ci ", "contains"]
                return !skip.contains(where: { token.hasPrefix($0) })
            }
    }
}
