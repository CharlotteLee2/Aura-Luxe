//
//  ContentView.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import SwiftUI

struct ContentView: View {
    private enum AuthScreen {
        case landing
        case register
        case signIn
    }

    @State private var authScreen: AuthScreen = .landing
    @State private var showHome = false
    @State private var showOnboarding = false
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
                if isResolvingDestination {
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
                    case .landing:
                        landingView
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
    }

    private var landingView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.98, blue: 0.97),
                    Color(red: 0.88, green: 0.94, blue: 0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Auraluxe")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                    Text("Your personalized skincare guide")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        authScreen = .signIn
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .background(Color(red: 0.30, green: 0.63, blue: 0.55))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 0.30, green: 0.63, blue: 0.55).opacity(0.25), radius: 8, x: 0, y: 4)

                    Button {
                        authScreen = .register
                    } label: {
                        Text("Register")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.30, green: 0.63, blue: 0.55), lineWidth: 1.5)
                            )
                    }
                    .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
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
                showOnboarding = true
            }
        }

        await MainActor.run {
            isResolvingDestination = false
        }
    }
}
