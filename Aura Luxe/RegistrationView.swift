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
    @State private var isPasswordVisible = false

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
        trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    private var normalizedPhoneDigits: String {
        phoneNumber.filter(\.isNumber)
    }

    private var isPhoneValid: Bool {
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
                    VStack(spacing: 16) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.20))
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack(spacing: 0) {
                            methodPill(title: "Email", isSelected: registrationMethod == .email) {
                                registrationMethod = .email
                            }
                            methodPill(title: "Phone", isSelected: registrationMethod == .phone) {
                                registrationMethod = .phone
                            }
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.84, green: 0.92, blue: 0.92))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: fieldSpacing) {
                        if registrationMethod == .email {
                            fieldLabel("Email")
                            roundedTextField(text: $email, placeholder: "")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        } else {
                            fieldLabel("Phone Number")
                            roundedTextField(text: $phoneNumber, placeholder: "")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.phonePad)
                                .autocorrectionDisabled()
                        }

                        fieldLabel("First Name")
                        roundedTextField(text: $firstName, placeholder: "")
                            .textInputAutocapitalization(.words)

                        fieldLabel("Last Name")
                        roundedTextField(text: $lastName, placeholder: "")
                            .textInputAutocapitalization(.words)

                        fieldLabel("Password")
                        passwordField(text: $password)

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

                    VStack(spacing: bottomSpacing) {
                        Button {
                            Task {
                                await registerUser()
                            }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Next")
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
                        .disabled(isLoading || !isFormValid)
                        .opacity((isLoading || !isFormValid) ? 0.65 : 1)

                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
                            Button("Sign in") {
                                onSignInTap()
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.63, blue: 0.55))
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
                .padding(.vertical, 9)
                .background(isSelected ? Color(red: 0.30, green: 0.63, blue: 0.55) : Color.clear)
                .clipShape(Capsule())
                .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.58, blue: 0.58))
        }
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
            .font(.system(size: 26, weight: .regular))
            .foregroundStyle(Color(red: 0.39, green: 0.48, blue: 0.48))
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
