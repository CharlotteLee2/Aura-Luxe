import Foundation
import Supabase

final class BoardsService {
    private let client = SupabaseManage.shared.client

    private func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Boards CRUD

    func fetchBoards() async throws -> [Board] {
        let userID = try await currentUserID()

        struct BoardRow: Decodable {
            let id: UUID
            let name: String
        }
        let boardResponse = try await client
            .from("boards")
            .select("id, name")
            .eq("user_id", value: userID.uuidString)
            .order("created_at", ascending: true)
            .execute()
        let boardRows = try JSONDecoder().decode([BoardRow].self, from: boardResponse.data)
        guard !boardRows.isEmpty else { return [] }

        struct BPRow: Decodable {
            let boardId: UUID
            let productName: String
            enum CodingKeys: String, CodingKey {
                case boardId = "board_id"
                case productName = "product_name"
            }
        }
        let boardIDs = boardRows.map(\.id.uuidString)
        let bpResponse = try await client
            .from("board_products")
            .select("board_id, product_name")
            .in("board_id", values: boardIDs)
            .order("saved_at", ascending: true)
            .execute()
        let bpRows = try JSONDecoder().decode([BPRow].self, from: bpResponse.data)

        var countByBoard: [UUID: Int] = [:]
        var firstProductByBoard: [UUID: String] = [:]
        for row in bpRows {
            countByBoard[row.boardId, default: 0] += 1
            if firstProductByBoard[row.boardId] == nil {
                firstProductByBoard[row.boardId] = row.productName
            }
        }

        var imageByProduct: [String: String] = [:]
        let coverNames = Array(Set(firstProductByBoard.values))
        if !coverNames.isEmpty {
            struct PRow: Decodable {
                let productName: String
                let imageURL: String?
                enum CodingKeys: String, CodingKey {
                    case productName = "product_name"
                    case imageURL = "image_url"
                }
            }
            let imgResponse = try await client
                .from("products")
                .select("product_name, image_url")
                .in("product_name", values: coverNames)
                .execute()
            let imgRows = try JSONDecoder().decode([PRow].self, from: imgResponse.data)
            for row in imgRows { if let url = row.imageURL { imageByProduct[row.productName] = url } }
        }

        return boardRows.map { row in
            Board(
                id: row.id,
                name: row.name,
                productCount: countByBoard[row.id, default: 0],
                coverImageURL: firstProductByBoard[row.id].flatMap { imageByProduct[$0] }
            )
        }
    }

    @discardableResult
    func createBoard(name: String) async throws -> Board {
        let userID = try await currentUserID()
        struct Insert: Encodable { let user_id: String; let name: String }
        struct Row: Decodable { let id: UUID; let name: String }
        let response = try await client
            .from("boards")
            .insert(Insert(user_id: userID.uuidString, name: name))
            .select("id, name")
            .single()
            .execute()
        let row = try JSONDecoder().decode(Row.self, from: response.data)
        return Board(id: row.id, name: row.name, productCount: 0, coverImageURL: nil)
    }

    func deleteBoard(id: UUID) async throws {
        try await client
            .from("boards")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func renameBoard(id: UUID, newName: String) async throws {
        struct Patch: Encodable { let name: String }
        try await client
            .from("boards")
            .update(Patch(name: newName))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Board products

    func addProduct(productName: String, toBoardID boardID: UUID) async throws {
        let userID = try await currentUserID()
        struct Insert: Encodable { let board_id: String; let user_id: String; let product_name: String }
        try await client
            .from("board_products")
            .insert(Insert(board_id: boardID.uuidString, user_id: userID.uuidString, product_name: productName))
            .execute()
    }

    func removeProduct(productName: String, fromBoardID boardID: UUID) async throws {
        try await client
            .from("board_products")
            .delete()
            .eq("board_id", value: boardID.uuidString)
            .eq("product_name", value: productName)
            .execute()
    }

    func fetchProducts(inBoardID boardID: UUID) async throws -> [RecommendedProduct] {
        struct BPRow: Decodable {
            let productName: String
            enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }
        let bpResponse = try await client
            .from("board_products")
            .select("product_name")
            .eq("board_id", value: boardID.uuidString)
            .order("saved_at", ascending: false)
            .execute()
        let bpRows = try JSONDecoder().decode([BPRow].self, from: bpResponse.data)
        guard !bpRows.isEmpty else { return [] }

        let names = bpRows.map(\.productName)
        let productResponse = try await client
            .from("products")
            .select("product_name, ingredients, skin_types, image_url")
            .in("product_name", values: names)
            .execute()
        let all = try JSONDecoder().decode([RecommendedProduct].self, from: productResponse.data)
        let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
        return bpRows.compactMap { byName[$0.productName] }
    }

    func boardIDsContaining(productName: String) async throws -> Set<UUID> {
        let userID = try await currentUserID()
        struct Row: Decodable {
            let boardId: UUID
            enum CodingKeys: String, CodingKey { case boardId = "board_id" }
        }
        let response = try await client
            .from("board_products")
            .select("board_id")
            .eq("user_id", value: userID.uuidString)
            .eq("product_name", value: productName)
            .execute()
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return Set(rows.map(\.boardId))
    }

    func fetchBoardedProductNames() async throws -> Set<String> {
        let userID = try await currentUserID()
        struct Row: Decodable {
            let productName: String
            enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }
        let response = try await client
            .from("board_products")
            .select("product_name")
            .eq("user_id", value: userID.uuidString)
            .execute()
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return Set(rows.map(\.productName))
    }
}
