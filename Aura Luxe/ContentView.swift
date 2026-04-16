//
//  ContentView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Group {
                if showSplash {
                    VStack {
                        Text("Auraluxe")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                } else {
                    RegistrationView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}

