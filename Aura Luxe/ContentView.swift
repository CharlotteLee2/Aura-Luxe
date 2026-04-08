//
//  ContentView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ProductsViewModel()

    var body: some View {
        VStack {
            Text("Auraluxe")
                .font(.largeTitle)
        }
        .task {
            await vm.runStartupScrape()
        }
    }
}

