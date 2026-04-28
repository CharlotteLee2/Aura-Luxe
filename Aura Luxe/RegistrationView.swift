import SwiftUI
import Supabase

struct RegistrationView: View {
    private enum RegistrationMethod {
        case phone
        case email
    }

    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var password = ""
    @State private var registrationMethod: RegistrationMethod = .email
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let authService: AuthServicing
    private let onSignInTap: () -> Void
    private let onRegistrationSuccess: () -> Void

    init(
        authService: AuthServicing = SupabaseAuthService(),
        onSignInTap: @escaping () -> Void = {},
        onRegistrationSuccess: @escaping () -> Void = {}
    ) {
        self.authService = authService
        self.onSignInTap = onSignInTap
        self.onRegistrationSuccess = onRegistrationSuccess
    }

    private var minLengthProgress: CGFloat {
        min(CGFloat(password.count) / 8, 1)
    }

    private var hasCapitalProgress: CGFloat {
        password.range(of: "[A-Z]", options: .regularExpression) == nil ? 0 : 1
    }

    private var hasNumberProgress: CGFloat {
        password.range(of: "[0-9]", options: .regularExpression) == nil ? 0 : 1
    }

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        // Lightweight prototype validation.
        trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    private var normalizedPhoneDigits: String {
        phoneNumber.filter(\.isNumber)
    }

    private var isPhoneValid: Bool {
        // Simple "valid phone" check: 10-15 digits (covers most E.164 lengths).
        (10...15).contains(normalizedPhoneDigits.count)
    }

    private var canSubmit: Bool {
        minLengthProgress >= 1 && hasCapitalProgress >= 1 && hasNumberProgress >= 1
    }

    private var isIdentifierValid: Bool {
        switch registrationMethod {
        case .email:
            return !trimmedEmail.isEmpty && isEmailValid
        case .phone:
            return !normalizedPhoneDigits.isEmpty && isPhoneValid
        }
    }

    private var isFormValid: Bool {
        !trimmedFirstName.isEmpty && !trimmedLastName.isEmpty && isIdentifierValid && canSubmit
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            GeometryReader { geometry in
                let sectionSpacing: CGFloat = 12
                let fieldSpacing: CGFloat = 16
                let bottomSpacing: CGFloat = 10

                VStack(spacing: 0) {
                    // Top section (fixed)
                    VStack(spacing: sectionSpacing) {
                        Text("Registration")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 0) {
                            methodPill(title: "Phone", isSelected: registrationMethod == .phone) {
                                registrationMethod = .phone
                            }
                            methodPill(title: "Email", isSelected: registrationMethod == .email) {
                                registrationMethod = .email
                            }
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }

                    // Middle section (centered-ish)
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: fieldSpacing) {
                        if registrationMethod == .email {
                            fieldLabel("Email")
                            roundedTextField(text: $email, isSecure: false, placeholder: "")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        } else {
                            fieldLabel("Phone Number")
                            roundedTextField(text: $phoneNumber, isSecure: false, placeholder: "")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.phonePad)
                                .autocorrectionDisabled()
                        }

                        fieldLabel("First Name")
                        roundedTextField(text: $firstName, isSecure: false, placeholder: "")
                            .textInputAutocapitalization(.words)

                        fieldLabel("Last Name")
                        roundedTextField(text: $lastName, isSecure: false, placeholder: "")
                            .textInputAutocapitalization(.words)

                        fieldLabel("Password")
                        roundedTextField(text: $password, isSecure: true, placeholder: "")

                        HStack(spacing: 8) {
                            passwordRule(
                                "min 8 letters",
                                progress: minLengthProgress,
                                color: minLengthColor
                            )
                            passwordRule(
                                "1 capital letter",
                                progress: hasCapitalProgress,
                                color: hasCapitalProgress == 1 ? .green : .red
                            )
                            passwordRule(
                                "1 number",
                                progress: hasNumberProgress,
                                color: hasNumberProgress == 1 ? .green : .red
                            )
                        }
                        .animation(.easeInOut(duration: 0.25), value: password)
                    }

                    Spacer(minLength: 0)

                    // Bottom section (anchored)
                    VStack(spacing: bottomSpacing) {
                        Button {
                            Task {
                                await registerUser()
                            }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("Next")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .background(Color(.systemGray4))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(isLoading || !isFormValid)
                        .opacity((isLoading || !isFormValid) ? 0.65 : 1)

                        HStack(spacing: 4) {
                            Text("Do you already have an account?")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                            Button("Sign in") {
                                onSignInTap()
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .underline()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

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

    private func methodPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color(.systemGray4) : Color.clear)
                .clipShape(Capsule())
        }
        .foregroundStyle(.black)
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

    private var minLengthColor: Color {
        if minLengthProgress == 0 {
            return .red
        } else if minLengthProgress < 1 {
            return .orange
        } else {
            return .green
        }
    }

    private func passwordRule(_ text: String, progress: CGFloat, color: Color) -> some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray3))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
                .animation(.easeInOut(duration: 0.25), value: progress)
            }
            .frame(height: 6)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.darkGray))
        }
    }

    private func socialIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(.black)
    }

    private func registerUser() async {
        errorMessage = nil
        successMessage = nil

        guard isFormValid else {
            errorMessage = "Please fill in all fields."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch registrationMethod {
            case .email:
                try await authService.signUpWithEmail(
                    email: trimmedEmail,
                    password: password,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName
                )
            case .phone:
                let e164 = "+" + normalizedPhoneDigits
                try await authService.signUpWithPhone(
                    phone: e164,
                    password: password,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName
                )
            }
            successMessage = nil
            email = ""
            phoneNumber = ""
            firstName = ""
            lastName = ""
            password = ""
            await MainActor.run {
                onRegistrationSuccess()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

protocol AuthServicing {
    func signUpWithEmail(email: String, password: String, firstName: String, lastName: String) async throws
    func signUpWithPhone(phone: String, password: String, firstName: String, lastName: String) async throws
}

struct SupabaseAuthService: AuthServicing {
    private static let nameMetadata: (String, String) -> [String: AnyJSON] = { first, last in
        [
            "first_name": .string(first),
            "last_name": .string(last),
        ]
    }

    func signUpWithEmail(email: String, password: String, firstName: String, lastName: String) async throws {
        _ = try await SupabaseManage.shared.client.auth.signUp(
            email: email,
            password: password,
            data: Self.nameMetadata(firstName, lastName)
        )
    }

    func signUpWithPhone(phone: String, password: String, firstName: String, lastName: String) async throws {
        _ = try await SupabaseManage.shared.client.auth.signUp(
            phone: phone,
            password: password,
            data: Self.nameMetadata(firstName, lastName)
        )
    }
}
