import Foundation
import CoreGraphics

struct ProductModeParser {
    private let noisePatterns = ["www.", ".com", "net wt", "fl oz", "made in", " lot ", "exp ", "mfg ", "distributed", "manufactured", "©", "®", "™"]
    private let terminators = ["directions", "how to use", "warnings", "caution", "net wt", "www.", "distributed by", "manufactured"]

    func parse(observations: [(text: String, rect: CGRect)]) -> (brand: String?, productName: String) {
        // Vision uses bottom-left origin; sort top-to-bottom by descending minY
        let sorted = observations
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
        let brandRaw = rankSorted.first?.text
        let nameRaw = rankSorted.count > 1 ? rankSorted[1].text : rankSorted.first?.text

        return (
            brand: brandRaw.map(clean),
            productName: nameRaw.map(clean) ?? ""
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
    private let startMarkers = ["ingredients:", "ingredients", "ingr.", "inci:", "active ingredients:"]
    private let terminators = ["directions", "how to use", "warnings", "caution:", "net wt", "www.", "distributed by", "manufactured"]

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

        // Split and clean
        return ingredientText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                guard token.count >= 2 else { return false }
                guard token.rangeOfCharacter(from: .letters) != nil else { return false }
                let skip = ["and", "may contain", "ci ", "contains"]
                return !skip.contains(where: { token.lowercased().hasPrefix($0) })
            }
            .map { $0.lowercased() }
    }
}
