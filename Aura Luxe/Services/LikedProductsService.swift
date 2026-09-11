import Foundation
import Supabase

final class LikedProductsService {
    private let client = SupabaseManage.shared.client

    private func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    /// Returns a Set<String> of liked product names for O(1) membership checks.
    func fetchLikedProductNames() async throws -> Set<String> {
        let userID = try await currentUserID()
        let response = try await client
            .from("liked_products")
            .select("product_name")
            .eq("user_id", value: userID.uuidString)
            .execute()

        struct Row: Decodable {
            let productName: String
            enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return Set(rows.map(\.productName))
    }

    /// Fetches full product details for the user's liked products, newest first.
    func fetchLikedProducts() async throws -> [RecommendedProduct] {
        let userID = try await currentUserID()

        let likedResponse = try await client
            .from("liked_products")
            .select("product_name, liked_at")
            .eq("user_id", value: userID.uuidString)
            .order("liked_at", ascending: false)
            .execute()

        struct LikedRow: Decodable {
            let productName: String
            enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }
        let likedRows = try JSONDecoder().decode([LikedRow].self, from: likedResponse.data)
        guard !likedRows.isEmpty else { return [] }

        let names = likedRows.map(\.productName)

        let productsResponse = try await client
            .from("products")
            .select("product_name, ingredients, skin_types, image_url")
            .in("product_name", values: names)
            .execute()

        let all = try JSONDecoder().decode([RecommendedProduct].self, from: productsResponse.data)
        let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
        return likedRows.compactMap { byName[$0.productName] }
    }

    func like(productName: String) async throws {
        let userID = try await currentUserID()
        struct Row: Encodable { let user_id: String; let product_name: String }
        try await client
            .from("liked_products")
            .insert(Row(user_id: userID.uuidString, product_name: productName))
            .execute()
    }

    func unlike(productName: String) async throws {
        let userID = try await currentUserID()
        try await client
            .from("liked_products")
            .delete()
            .eq("user_id", value: userID.uuidString)
            .eq("product_name", value: productName)
            .execute()
    }

    func toggleLike(productName: String, currentlyLiked: Bool) async throws -> Bool {
        if currentlyLiked {
            try await unlike(productName: productName)
            return false
        } else {
            try await like(productName: productName)
            return true
        }
    }
}
