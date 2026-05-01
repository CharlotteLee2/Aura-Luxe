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
    @State private var showHome = false
    @State private var showOnboarding = false
    /// Shown on Sign In only after a successful registration in this session.
    @State private var showAccountCreatedBanner = false
    @State private var isResolvingDestination = false

    private let onboardingService: OnboardingQuizServicing

    init(onboardingService: OnboardingQuizServicing = SupabaseOnboardingQuizService()) {
        self.onboardingService = onboardingService
    }

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
                } else if isResolvingDestination {
                    ProgressView()
                } else if showHome {
                    MainTabView()
                } else if showOnboarding {
                    OnboardingQuizView(
                        service: onboardingService,
                        onCompletion: {
                            showOnboarding = false
                            showHome = true
                        }
                    )
                } else {
                    switch authScreen {
                    case .register:
                        RegistrationView(
                            onSignInTap: {
                                showAccountCreatedBanner = false
                                authScreen = .signIn
                            },
                            onRegistrationSuccess: {
                                showAccountCreatedBanner = true
                                authScreen = .signIn
                            }
                        )
                    case .signIn:
                        SignInView(
                            showAccountCreatedBanner: showAccountCreatedBanner,
                            onRegisterTap: {
                                showAccountCreatedBanner = false
                                authScreen = .register
                            },
                            onSignInSuccess: {
                                Task {
                                    await routePostSignIn()
                                }
                            }
                        )
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

    private func routePostSignIn() async {
        await MainActor.run {
            isResolvingDestination = true
            showHome = false
            showOnboarding = false
        }

        do {
            let hasCompleted = try await onboardingService.hasCompletedOnboarding()
            await MainActor.run {
                if hasCompleted {
                    showHome = true
                } else {
                    showOnboarding = true
                }
            }
        } catch {
            await MainActor.run {
                // If completion lookup fails, force onboarding so the user can continue.
                showOnboarding = true
            }
        }

        await MainActor.run {
            isResolvingDestination = false
        }
    }
}

