import Foundation

struct Board: Identifiable {
    let id: UUID
    let name: String
    var productCount: Int
    var coverImageURL: String?
}
