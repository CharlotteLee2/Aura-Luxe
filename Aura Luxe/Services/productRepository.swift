//
//  productRepository.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 1/7/26.
//

import Foundation
import Supabase

final class productRepository {

    private let client = SupabaseManage.shared.client

    func save(_ product: products) async throws {
        try await client
            .from("products")
            .insert(product)
            .execute()
    }
}

