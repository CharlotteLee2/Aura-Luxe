//
//  SupaBaseManage.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/26/25.
//
import Supabase
import Foundation

class SupabaseManage {
    static let shared = SupabaseManage()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://ttftciroyrdbskixmynz.supabase.co")!,
            supabaseKey: "sb_publishable_7hIhIl6R3silizruFmOqPQ_C7CYSSqG",
            options: .init(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
