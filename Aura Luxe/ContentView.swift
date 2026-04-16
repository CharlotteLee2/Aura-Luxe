//
//  ContentView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI

struct ContentView: View {
    private enum AuthScreen {
        case register
        case signIn
    }

    @State private var showSplash = true
    @State private var authScreen: AuthScreen = .register

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
                    switch authScreen {
                    case .register:
                        RegistrationView {
                            authScreen = .signIn
                        }
                    case .signIn:
                        SignInView {
                            authScreen = .register
                        }
                    }
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

