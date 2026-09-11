import Foundation
import Supabase

final class RecommendedProductsService {
    private let client = SupabaseManage.shared.client

    private func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    func fetchRecommendedProducts(limit: Int = 8) async throws -> [RecommendedProduct] {
        let userID = try await currentUserID()

        var skinFilter: [String] = ["all"]

        let quizResponse = try await client
            .from("onboarding_quiz_responses")
            .select("skin_after_cleansing, oiliness_during_day, sensitivity_level")
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()

        struct QuizRow: Decodable {
            let skinAfterCleansing: String
            let oilinessDuringDay: String
            let sensitivityLevel: String
            enum CodingKeys: String, CodingKey {
                case skinAfterCleansing = "skin_after_cleansing"
                case oilinessDuringDay  = "oiliness_during_day"
                case sensitivityLevel   = "sensitivity_level"
            }
        }

        if let quiz = try? JSONDecoder().decode([QuizRow].self, from: quizResponse.data).first {
            if quiz.skinAfterCleansing.lowercased().contains("tight") ||
               quiz.skinAfterCleansing.lowercased().contains("dry") {
                skinFilter.append("dry")
            }
            if quiz.skinAfterCleansing.lowercased().contains("oily") ||
               quiz.oilinessDuringDay.lowercased().contains("often") {
                skinFilter.append("oily")
            }
            if quiz.sensitivityLevel.lowercased().contains("sensitive") {
                skinFilter.append("sensitive")
            }
        }

        let response = try await client
            .from("products")
            .select("product_name, ingredients, skin_types, image_url")
            .overlaps("skin_types", value: skinFilter)
            .limit(limit)
            .execute()

        return try JSONDecoder().decode([RecommendedProduct].self, from: response.data)
    }
}
