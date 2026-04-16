import SwiftUI
import Supabase

struct SignInView: View {
    @State private var identifier = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let authService: SignInServicing
    private let onRegisterTap: () -> Void

    init(authService: SignInServicing = SupabaseSignInService(), onRegisterTap: @escaping () -> Void = {}) {
        self.authService = authService
        self.onRegisterTap = onRegisterTap
    }

    private var trimmedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPhoneDigits: String {
        trimmedIdentifier.filter(\.isNumber)
    }

    private var isEmailMode: Bool {
        trimmedIdentifier.contains("@")
    }

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
            Color(.systemGray6).ignoresSafeArea()

            GeometryReader { geometry in
                let sectionSpacing: CGFloat = 12
                let fieldSpacing: CGFloat = 16
                let bottomSpacing: CGFloat = 10

                VStack(spacing: 0) {
                    VStack(spacing: sectionSpacing) {
                        Text("Sign In")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: fieldSpacing) {
                        fieldLabel("Email/Phone Number")
                        roundedTextField(text: $identifier, isSecure: false, placeholder: "")
                            .textInputAutocapitalization(.never)
                            .keyboardType(isEmailMode ? .emailAddress : .phonePad)
                            .autocorrectionDisabled()

                        fieldLabel("Password")
                        roundedTextField(text: $password, isSecure: true, placeholder: "")

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
                                .foregroundStyle(.black)
                            }

                            Spacer()

                            Button("Forgot Password?") {
                                // TODO: wire password reset flow
                            }
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.black)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: bottomSpacing) {
                        Button {
                            Task {
                                await signIn()
                            }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .background(Color(.systemGray4))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(isLoading || !canSubmit)
                        .opacity((isLoading || !canSubmit) ? 0.65 : 1)

                        HStack(spacing: 4) {
                            Text("Are you new?")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                            Button("Register") {
                                onRegisterTap()
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .underline()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        Text("Sign In")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 26) {
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
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.black)
    }

    private func roundedTextField(text: Binding<String>, isSecure: Bool, placeholder: String) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray3), lineWidth: 2)
        )
    }

    private func socialIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(.black)
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

            successMessage = "Signed in successfully."
        } catch {
            errorMessage = error.localizedDescription
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
