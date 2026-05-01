import Foundation
import Supabase

struct ProductSearchService {
    private let client = SupabaseManage.shared.client

    func search(query: String, limit: Int = 50) async throws -> [RecommendedProduct] {
        let response = try await client
            .from("products")
            .select("product_name, ingredients, skin_types, image_url")
            .ilike("product_name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
        return try JSONDecoder().decode([RecommendedProduct].self, from: response.data)
    }
}
