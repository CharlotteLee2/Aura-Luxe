import Foundation

enum ConflictSeverity { case avoid, caution }

struct ConflictRule {
    let a: String
    let b: String
    let message: String
    let severity: ConflictSeverity
}

struct IngredientConflict: Equatable {
    let ingredientA: String
    let ingredientB: String
    let message: String
    let severity: ConflictSeverity

    static func == (lhs: IngredientConflict, rhs: IngredientConflict) -> Bool {
        lhs.ingredientA == rhs.ingredientA && lhs.ingredientB == rhs.ingredientB
    }
}

struct ConflictDetectionService {
    static let rules: [ConflictRule] = [
        .init(a: "retinol",          b: "glycolic acid",    message: "AHAs can deactivate retinol and increase skin irritation.",           severity: .avoid),
        .init(a: "retinol",          b: "lactic acid",      message: "AHAs reduce retinol's efficacy and increase sensitivity.",            severity: .avoid),
        .init(a: "retinol",          b: "aha",              message: "AHAs reduce retinol's efficacy and increase sensitivity.",            severity: .avoid),
        .init(a: "retinol",          b: "salicylic acid",   message: "Salicylic acid may counteract retinol's effects.",                   severity: .caution),
        .init(a: "retinol",          b: "bha",              message: "BHAs with retinol can over-exfoliate the skin.",                     severity: .caution),
        .init(a: "retinol",          b: "vitamin c",        message: "Different pH requirements — use AM/PM to avoid neutralization.",      severity: .caution),
        .init(a: "retinol",          b: "ascorbic acid",    message: "Different pH requirements — use AM/PM to avoid neutralization.",      severity: .caution),
        .init(a: "retinol",          b: "benzoyl peroxide", message: "Benzoyl peroxide oxidizes retinol, rendering it ineffective.",        severity: .avoid),
        .init(a: "benzoyl peroxide", b: "vitamin c",        message: "Oxidation risk — these two may cancel each other's benefits.",        severity: .caution),
        .init(a: "benzoyl peroxide", b: "ascorbic acid",    message: "Oxidation risk — these two may cancel each other's benefits.",        severity: .caution),
        .init(a: "vitamin c",        b: "niacinamide",      message: "May reduce vitamin C's efficacy — separate use by 30 minutes.",       severity: .caution),
        .init(a: "ascorbic acid",    b: "niacinamide",      message: "May reduce vitamin C's efficacy — separate use by 30 minutes.",       severity: .caution),
        .init(a: "glycolic acid",    b: "salicylic acid",   message: "Stacking acids can over-exfoliate and irritate the skin.",            severity: .caution),
        .init(a: "aha",              b: "bha",              message: "Stacking acid types can over-exfoliate — use on alternating days.",   severity: .caution),
    ]

    func detect(scannedIngredients: [String], routineIngredients: [String]) -> [IngredientConflict] {
        detect(ingredientsA: scannedIngredients, ingredientsB: routineIngredients)
    }

    func detect(ingredientsA: [String], ingredientsB: [String]) -> [IngredientConflict] {
        let lowerA = ingredientsA.map { $0.lowercased() }
        let lowerB = ingredientsB.map { $0.lowercased() }

        var seen = Set<String>()
        var result: [IngredientConflict] = []

        for rule in Self.rules {
            let aInA = lowerA.contains { $0.contains(rule.a) }
            let bInB = lowerB.contains { $0.contains(rule.b) }
            let aInB = lowerB.contains { $0.contains(rule.a) }
            let bInA = lowerA.contains { $0.contains(rule.b) }

            let key = "\(rule.a)|\(rule.b)"
            let reverseKey = "\(rule.b)|\(rule.a)"
            guard !seen.contains(key), !seen.contains(reverseKey) else { continue }

            if (aInA && bInB) || (aInB && bInA) {
                result.append(IngredientConflict(
                    ingredientA: rule.a.capitalized,
                    ingredientB: rule.b.capitalized,
                    message: rule.message,
                    severity: rule.severity
                ))
                seen.insert(key)
            }
        }
        return result
    }
}
