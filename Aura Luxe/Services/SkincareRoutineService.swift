import Foundation
import Supabase

struct SkincareRoutineEntry: Encodable {
    let user_id: UUID
    let product_name: String
    let time_of_use: String
}

struct SkincareRoutineService {
    private let client = SupabaseManage.shared.client

    func save(entries: [SkincareRoutineEntry]) async throws {
        guard !entries.isEmpty else { return }
        try await client.from("skincare_routine").insert(entries).execute()
    }

    func authenticatedUserID() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }
}
