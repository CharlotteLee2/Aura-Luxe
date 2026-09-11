import Foundation

enum HighlightSentiment { case beneficial, caution, warning }

struct IngredientHighlight: Equatable {
    let keyword: String
    let label: String
    let description: String
    let sentiment: HighlightSentiment

    static func == (lhs: IngredientHighlight, rhs: IngredientHighlight) -> Bool {
        lhs.keyword == rhs.keyword
    }
}

struct IngredientHighlightDictionary {
    private static let entries: [IngredientHighlight] = [
        .init(keyword: "niacinamide",       label: "Oil Control",           description: "Minimizes pores and controls sebum",                  sentiment: .beneficial),
        .init(keyword: "hyaluronic acid",   label: "Deep Hydration",        description: "Draws moisture deep into the skin",                   sentiment: .beneficial),
        .init(keyword: "retinol",           label: "Anti-Aging",            description: "Speeds cell turnover and reduces fine lines",          sentiment: .beneficial),
        .init(keyword: "ascorbic acid",     label: "Brightening",           description: "Fades dark spots and evens skin tone",                sentiment: .beneficial),
        .init(keyword: "vitamin c",         label: "Brightening",           description: "Fades dark spots and evens skin tone",                sentiment: .beneficial),
        .init(keyword: "tocopherol",        label: "Antioxidant",           description: "Protects skin from free radical damage",              sentiment: .beneficial),
        .init(keyword: "vitamin e",         label: "Antioxidant",           description: "Protects skin from free radical damage",              sentiment: .beneficial),
        .init(keyword: "ceramide",          label: "Barrier Repair",        description: "Restores and strengthens the skin barrier",           sentiment: .beneficial),
        .init(keyword: "glycerin",          label: "Humectant",             description: "Locks in moisture for softer skin",                   sentiment: .beneficial),
        .init(keyword: "squalane",          label: "Lightweight Moisture",  description: "Mimics skin's natural oils, non-comedogenic",         sentiment: .beneficial),
        .init(keyword: "peptide",           label: "Firming",               description: "Stimulates collagen production",                      sentiment: .beneficial),
        .init(keyword: "salicylic acid",    label: "Acne Fighter",          description: "Unclogs pores and reduces blackheads",                sentiment: .caution),
        .init(keyword: "glycolic acid",     label: "Exfoliating AHA",       description: "Removes dead skin cells for a brighter complexion",   sentiment: .caution),
        .init(keyword: "lactic acid",       label: "Gentle Exfoliant",      description: "Smooths texture with less irritation than glycolic",  sentiment: .caution),
        .init(keyword: "benzoyl peroxide",  label: "Antibacterial",         description: "Kills acne bacteria but may cause dryness",           sentiment: .caution),
        .init(keyword: "alpha arbutin",     label: "Brightening",           description: "Inhibits melanin for a more even skin tone",          sentiment: .beneficial),
        .init(keyword: "azelaic acid",      label: "Redness Reducer",       description: "Calms redness and kills acne bacteria",               sentiment: .beneficial),
        .init(keyword: "panthenol",         label: "Soothing",              description: "Calms irritation and supports skin healing",          sentiment: .beneficial),
        .init(keyword: "allantoin",         label: "Healing",               description: "Promotes skin cell regeneration",                     sentiment: .beneficial),
        .init(keyword: "tranexamic acid",   label: "Dark Spot Corrector",   description: "Targets hyperpigmentation effectively",               sentiment: .beneficial),
        .init(keyword: "kojic acid",        label: "Brightening",           description: "Fades discoloration over time",                       sentiment: .caution),
        .init(keyword: "zinc",              label: "Calming",               description: "Reduces oil production and soothes inflammation",     sentiment: .beneficial),
        .init(keyword: "centella",          label: "Repair",                description: "Promotes wound healing and collagen synthesis",       sentiment: .beneficial),
        .init(keyword: "mineral oil",       label: "Occlusive",             description: "Creates a protective barrier, may clog pores",        sentiment: .caution),
        .init(keyword: "fragrance",         label: "Possible Irritation",   description: "Common allergen for sensitive skin",                  sentiment: .warning),
        .init(keyword: "parfum",            label: "Possible Irritation",   description: "Fragrance compound — potential sensitizer",           sentiment: .warning),
        .init(keyword: "alcohol denat",     label: "Drying",                description: "Can disrupt the skin barrier with overuse",           sentiment: .warning),
        .init(keyword: "sd alcohol",        label: "Drying",                description: "Volatile alcohol — may dry out skin",                 sentiment: .warning),
    ]

    func highlights(for ingredients: [String]) -> [IngredientHighlight] {
        var seen = Set<String>()
        var result: [IngredientHighlight] = []
        for ingredient in ingredients {
            let lower = ingredient.lowercased()
            for entry in Self.entries {
                guard !seen.contains(entry.keyword) else { continue }
                if lower.contains(entry.keyword) {
                    result.append(entry)
                    seen.insert(entry.keyword)
                }
            }
        }
        return result
    }
}
