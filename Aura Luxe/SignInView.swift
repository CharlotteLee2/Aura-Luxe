import SwiftUI
import Supabase

struct SignInView: View {
    @State private var identifier = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isPasswordVisible = false

    private let showAccountCreatedBanner: Bool
    private let authService: SignInServicing
    private let onRegisterTap: () -> Void
    private let onSignInSuccess: () -> Void

    init(
        showAccountCreatedBanner: Bool = false,
        authService: SignInServicing = SupabaseSignInService(),
        onRegisterTap: @escaping () -> Void = {},
        onSignInSuccess: @escaping () -> Void = {}
    ) {
        self.showAccountCreatedBanner = showAccountCreatedBanner
        self.authService = authService
        self.onRegisterTap = onRegisterTap
        self.onSignInSuccess = onSignInSuccess
    }

    private var trimmedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPhoneDigits: String {
        trimmedIdentifier.filter(\.isNumber)
    }

    private var isPhoneMode: Bool {
        !trimmedIdentifier.isEmpty
            && trimmedIdentifier.allSatisfy { $0.isNumber || $0 == "+" || $0 == "-" || $0 == " " || $0 == "(" || $0 == ")" }
    }

    private var isEmailMode: Bool { !isPhoneMode }

    private var isValidEmail: Bool {
        trimmedIdentifier.contains("@") && trimmedIdentifier.contains(".")
    }

    private var isValidPhone: Bool {
        (10...15).contains(normalizedPhoneDigits.count)
    }

    private var canSubmit: Bool {
        !password.isEmpty && (isEmailMode ? isValidEmail : isValidPhone)
    }

    var body: some View {
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

            GeometryReader { geometry in
                let fieldSpacing: CGFloat = 20
                let bottomSpacing: CGFloat = 10

                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("Sign In")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 4)

                    VStack(alignment: .leading, spacing: fieldSpacing) {
                        if showAccountCreatedBanner {
                            Text("Account created! Please verify your account in Gmail first, then sign in.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        fieldLabel("Email / Phone Number")
                        roundedTextField(text: $identifier, placeholder: "")
                            .textInputAutocapitalization(.never)
                            .keyboardType(isPhoneMode ? .phonePad : .emailAddress)
                            .autocorrectionDisabled()

                        fieldLabel("Password")
                        passwordField(text: $password)

                        HStack {
                            Button {
                                rememberMe.toggle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16))
                                    Text("Remember Me")
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                }
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                            }

                            Spacer()

                            Button("Forgot Password?") {
                                // TODO: wire password reset flow
                            }
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                        }
                        .padding(.bottom, 40)

                        Button {
                            Task {
                                await signIn()
                            }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .background(Color(red: 0.30, green: 0.63, blue: 0.55))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(red: 0.30, green: 0.63, blue: 0.55).opacity(0.25), radius: 8, x: 0, y: 4)
                        .disabled(isLoading || !canSubmit)
                        .opacity((isLoading || !canSubmit) ? 0.65 : 1)

                        HStack(spacing: 4) {
                            Text("Are you new?")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                            Button("Register") {
                                onRegisterTap()
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
                            .underline()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 16)

                    VStack(spacing: bottomSpacing) {
                        Text("Or sign in with")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.55, green: 0.63, blue: 0.63))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 30) {
                            socialIcon("f.cursive")
                            socialIcon("camera")
                            socialIcon("envelope")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }

                        if let successMessage {
                            Text(successMessage)
                                .font(.footnote)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: min(geometry.size.width - 40, 430))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .foregroundStyle(.primary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
    }

    private func roundedTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.70, green: 0.82, blue: 0.82), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func passwordField(text: Binding<String>) -> some View {
        HStack(spacing: 0) {
            Group {
                if isPasswordVisible {
                    TextField("", text: text)
                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                } else {
                    SecureField("", text: text)
                        .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                }
            }
            .padding(.leading, 16)
            .frame(height: 48)

            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                    .frame(width: 44, height: 48)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 0.70, green: 0.82, blue: 0.82), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func socialIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
    }

    private func signIn() async {
        errorMessage = nil
        successMessage = nil

        guard canSubmit else {
            errorMessage = "Please enter a valid email/phone and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if isEmailMode {
                try await authService.signInWithEmail(email: trimmedIdentifier, password: password)
            } else {
                let e164 = "+" + normalizedPhoneDigits
                try await authService.signInWithPhone(phone: e164, password: password)
            }

            successMessage = nil
            await MainActor.run {
                onSignInSuccess()
            }
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("email not confirmed")
                || message.localizedCaseInsensitiveContains("not confirmed") {
                errorMessage = "Please confirm your email using the link we sent you, then sign in again."
            } else {
                errorMessage = message
            }
        }
    }
}

protocol SignInServicing {
    func signInWithEmail(email: String, password: String) async throws
    func signInWithPhone(phone: String, password: String) async throws
}

struct SupabaseSignInService: SignInServicing {
    func signInWithEmail(email: String, password: String) async throws {
        _ = try await SupabaseManage.shared.client.auth.signIn(
            email: email,
            password: password
        )
    }

    func signInWithPhone(phone: String, password: String) async throws {
        _ = try await SupabaseManage.shared.client.auth.signIn(
            phone: phone,
            password: password
        )
    }
}
