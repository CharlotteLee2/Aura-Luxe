import SwiftUI
import Supabase
import Foundation

struct OnboardingQuizView: View {
    private enum Step: Hashable {
        case skinAfterCleansing
        case oilyFrequency
        case sensitivity
        case concerns
        case breakoutFrequency
        case routine
        case preferences
    }

    private enum ConcernOption: String, CaseIterable {
        case acne = "Acne / breakouts"
        case darkSpots = "Dark spots"
        case dryness = "Dryness"
        case oiliness = "Oiliness"
        case redness = "Redness"
        case fineLines = "Fine lines"
        case unevenTexture = "Uneven texture"
    }

    private let service: OnboardingQuizServicing
    private let onCompletion: () -> Void

    @State private var currentStepIndex = 0
    @State private var singleAnswers: [Step: String] = [:]
    @State private var selectedConcerns: Set<ConcernOption> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        service: OnboardingQuizServicing = SupabaseOnboardingQuizService(),
        onCompletion: @escaping () -> Void = {}
    ) {
        self.service = service
        self.onCompletion = onCompletion
    }

    private var visibleSteps: [Step] {
        var steps: [Step] = [
            .skinAfterCleansing,
            .oilyFrequency,
            .sensitivity,
            .concerns,
        ]

        if selectedConcerns.contains(.acne) {
            steps.append(.breakoutFrequency)
        }

        steps.append(contentsOf: [.routine, .preferences])
        return steps
    }

    private var currentStep: Step {
        let safeIndex = min(currentStepIndex, visibleSteps.count - 1)
        return visibleSteps[safeIndex]
    }

    private var progressValue: CGFloat {
        CGFloat(currentStepIndex + 1) / CGFloat(max(visibleSteps.count, 1))
    }

    private var progressLabel: String {
        "\(currentStepIndex + 1)/\(visibleSteps.count)"
    }

    private var canGoBack: Bool {
        currentStepIndex > 0 && !isSubmitting
    }

    private var nextButtonTitle: String {
        currentStepIndex == visibleSteps.count - 1 ? "Finish" : "Next"
    }

    private var canContinue: Bool {
        switch currentStep {
        case .skinAfterCleansing, .oilyFrequency, .sensitivity, .breakoutFrequency, .routine, .preferences:
            return singleAnswers[currentStep] != nil
        case .concerns:
            return !selectedConcerns.isEmpty && selectedConcerns.count <= 3
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.97, blue: 0.96),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.95, green: 0.99, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 22) {
                    topSection
                    ScrollView(showsIndicators: false) {
                        VStack {
                            Spacer(minLength: 24)
                            questionSection
                            Spacer(minLength: 36)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height * 0.58, alignment: .center)
                        .padding(.bottom, 6)
                    }
                    Spacer(minLength: 0)
                    bottomSection
                }
                .frame(maxWidth: min(geometry.size.width - 40, 430))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(.primary)
        .onChange(of: selectedConcerns) { _, newValue in
            if !newValue.contains(.acne) {
                singleAnswers[.breakoutFrequency] = nil
            }
        }
        .onChange(of: visibleSteps.count) { _, newCount in
            if currentStepIndex >= newCount {
                currentStepIndex = max(0, newCount - 1)
            }
        }
    }

    private var topSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    guard canGoBack else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStepIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.85))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.72, green: 0.80, blue: 0.80), lineWidth: 1)
                        )
                }
                .foregroundStyle(canGoBack ? Color.black : Color.gray)
                .disabled(!canGoBack)

                Spacer()
            }

            VStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                        Capsule()
                            .fill(Color(red: 0.42, green: 0.71, blue: 0.67))
                            .frame(width: proxy.size.width * progressValue)
                    }
                }
                .frame(height: 12)

                Text(progressLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.38, green: 0.47, blue: 0.47))
            }
        }
    }

    private var questionSection: some View {
        VStack(spacing: 28) {
            Text(questionTitle(for: currentStep))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.18))

            VStack(spacing: 14) {
                ForEach(options(for: currentStep), id: \.self) { option in
                    optionCard(for: option)
                }
            }
        }
    }

    private var bottomSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await goToNextStep()
                }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(nextButtonTitle)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .background(Color(red: 0.30, green: 0.63, blue: 0.55))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .disabled(!canContinue || isSubmitting)
            .opacity((!canContinue || isSubmitting) ? 0.65 : 1)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func optionCard(for option: String) -> some View {
        let isSelected = isOptionSelected(option, in: currentStep)

        return Button {
            select(option: option, for: currentStep)
        } label: {
            HStack {
                Text(option)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(red: 0.11, green: 0.18, blue: 0.17))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? Color(red: 0.30, green: 0.63, blue: 0.55)
                            : Color(red: 0.66, green: 0.77, blue: 0.77)
                    )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected
                            ? Color(red: 0.30, green: 0.63, blue: 0.55)
                            : Color(red: 0.76, green: 0.86, blue: 0.86),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }

    private func questionTitle(for step: Step) -> String {
        switch step {
        case .skinAfterCleansing:
            return "After cleansing, how does your skin feel?"
        case .oilyFrequency:
            return "How often does your skin get oily during the day?"
        case .sensitivity:
            return "How sensitive is your skin?"
        case .concerns:
            return "What are your main skin concerns?\n(Select up to 3)"
        case .breakoutFrequency:
            return "How often do you break out?"
        case .routine:
            return "What's your current routine like?"
        case .preferences:
            return "Any product preferences?"
        }
    }

    private func options(for step: Step) -> [String] {
        switch step {
        case .skinAfterCleansing:
            return [
                "Tight/dry",
                "Comfortable",
                "Oily/shiny",
                "Oily in some areas, dry in others",
            ]
        case .oilyFrequency:
            return [
                "Never",
                "Sometimes (T-zone)",
                "Often (entire face)",
            ]
        case .sensitivity:
            return [
                "Not sensitive",
                "Slightly sensitive",
                "Very sensitive (reacts easily)",
            ]
        case .concerns:
            return ConcernOption.allCases.map(\.rawValue)
        case .breakoutFrequency:
            return [
                "Rarely",
                "Occasionally",
                "Frequently",
                "Constantly",
            ]
        case .routine:
            return [
                "No routine",
                "Basic (cleanser + moisturizer)",
                "Advanced (3+ steps)",
            ]
        case .preferences:
            return [
                "Fragrance-free",
                "Budget-friendly",
                "Luxury",
                "Clean ingredients",
                "No preference",
            ]
        }
    }

    private func isOptionSelected(_ option: String, in step: Step) -> Bool {
        switch step {
        case .concerns:
            return selectedConcerns.contains(where: { $0.rawValue == option })
        default:
            return singleAnswers[step] == option
        }
    }

    private func select(option: String, for step: Step) {
        errorMessage = nil
        switch step {
        case .concerns:
            guard let concern = ConcernOption(rawValue: option) else { return }
            if selectedConcerns.contains(concern) {
                selectedConcerns.remove(concern)
            } else if selectedConcerns.count < 3 {
                selectedConcerns.insert(concern)
            }
        default:
            singleAnswers[step] = option
        }
    }

    private func goToNextStep() async {
        guard canContinue else { return }
        let isLastStep = currentStepIndex == visibleSteps.count - 1
        if isLastStep {
            await submitQuiz()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentStepIndex += 1
            }
        }
    }

    private func submitQuiz() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = OnboardingQuizResponse(
                skinAfterCleansing: singleAnswers[.skinAfterCleansing] ?? "",
                oilinessDuringDay: singleAnswers[.oilyFrequency] ?? "",
                sensitivityLevel: singleAnswers[.sensitivity] ?? "",
                concerns: selectedConcerns.map(\.rawValue).sorted(),
                breakoutFrequency: selectedConcerns.contains(.acne) ? singleAnswers[.breakoutFrequency] : nil,
                routineLevel: singleAnswers[.routine] ?? "",
                productPreference: singleAnswers[.preferences] ?? ""
            )
            try await service.save(response: response)
            await MainActor.run {
                onCompletion()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OnboardingQuizResponse: Codable {
    let skinAfterCleansing: String
    let oilinessDuringDay: String
    let sensitivityLevel: String
    let concerns: [String]
    let breakoutFrequency: String?
    let routineLevel: String
    let productPreference: String

    enum CodingKeys: String, CodingKey {
        case skinAfterCleansing = "skin_after_cleansing"
        case oilinessDuringDay = "oiliness_during_day"
        case sensitivityLevel = "sensitivity_level"
        case concerns
        case breakoutFrequency = "breakout_frequency"
        case routineLevel = "routine_level"
        case productPreference = "product_preference"
    }
}

private struct OnboardingQuizRow: Encodable {
    let user_id: UUID
    let skin_after_cleansing: String
    let oiliness_during_day: String
    let sensitivity_level: String
    let concerns: [String]
    let breakout_frequency: String?
    let routine_level: String
    let product_preference: String
    let completed_at: String
}

private struct ProfileCompletedAtRow: Decodable {
    let completed_at: String?
}

protocol OnboardingQuizServicing {
    func hasCompletedOnboarding() async throws -> Bool
    func save(response: OnboardingQuizResponse) async throws
}

struct SupabaseOnboardingQuizService: OnboardingQuizServicing {
    private let client = SupabaseManage.shared.client
    private let isoFormatter = ISO8601DateFormatter()

    init() {
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func hasCompletedOnboarding() async throws -> Bool {
        let userID = try await authenticatedUserID()

        let response = try await client
            .from("profiles")
            .select("completed_at")
            .eq("id", value: userID.uuidString)
            .single()
            .execute()

        let profile = try JSONDecoder().decode(ProfileCompletedAtRow.self, from: response.data)
        return profile.completed_at != nil
    }

    func save(response: OnboardingQuizResponse) async throws {
        let userID = try await authenticatedUserID()
        let completedAt = isoFormatter.string(from: Date())

        let row = OnboardingQuizRow(
            user_id: userID,
            skin_after_cleansing: response.skinAfterCleansing,
            oiliness_during_day: response.oilinessDuringDay,
            sensitivity_level: response.sensitivityLevel,
            concerns: response.concerns,
            breakout_frequency: response.breakoutFrequency,
            routine_level: response.routineLevel,
            product_preference: response.productPreference,
            completed_at: completedAt
        )

        try await client
            .from("onboarding_quiz_responses")
            .upsert(row)
            .execute()

        try await client
            .from("profiles")
            .update(["completed_at": completedAt])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    private func authenticatedUserID() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }
}
