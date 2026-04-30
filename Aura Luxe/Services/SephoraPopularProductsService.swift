import Foundation
import Supabase

struct SephoraPopularProduct: Identifiable, Codable, Equatable {
    let slot: Int
    let name: String
    let subtitle: String
    let imageURL: String

    var id: Int { slot }

    enum CodingKeys: String, CodingKey {
        case slot
        case name
        case subtitle
        case imageURL = "image_url"
    }
}

final class SephoraPopularProductsService {
    private let client = SupabaseManage.shared.client
    // Replace with your deployed backend URL, for example:
    // https://your-service.onrender.com/refresh-sephora-popular
    private let backendRefreshURLString = "https://aura-luxe.onrender.com/refresh-sephora-popular"
    // Optional: set if your backend expects Authorization Bearer token.
    private let backendRefreshToken = "efe231ff4ec00276bd61fb9d3dc9174d"

    func fetchCachedPopularProducts() async throws -> [SephoraPopularProduct] {
        let response = try await client
            .from("sephora_popular_products_cache")
            .select("slot, name, subtitle, image_url")
            .order("slot", ascending: true)
            .execute()

        return try JSONDecoder().decode([SephoraPopularProduct].self, from: response.data)
    }

    /// Triggers a backend refresh request. Caller should still rely on cached data as fallback.
    func refreshViaBackend(timeoutSeconds: TimeInterval = 5) async throws {
        guard
            !backendRefreshURLString.contains("YOUR_BACKEND_URL"),
            let url = URL(string: backendRefreshURLString)
        else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !backendRefreshToken.isEmpty {
            request.setValue("Bearer \(backendRefreshToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = "{}".data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds + 1

        let session = URLSession(configuration: config)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

