import SwiftUI

struct IrritationLogSheet: View {
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private let service = HabitTrackerService()

    @State private var severity: Double = 2
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var notesFocused: Bool

    private let teal = Color(red: 0.30, green: 0.63, blue: 0.55)
    private let textDark = Color(red: 0.14, green: 0.20, blue: 0.20)
    private let textMid = Color(red: 0.39, green: 0.48, blue: 0.48)
    private let border = Color(red: 0.78, green: 0.88, blue: 0.88)

    private var severityEmoji: String {
        switch Int(severity) {
        case 1: return "😊"
        case 2: return "😐"
        case 3: return "😕"
        case 4: return "😣"
        default: return "😫"
        }
    }

    private var severityLabel: String {
        switch Int(severity) {
        case 1: return "None / Minimal"
        case 2: return "Mild"
        case 3: return "Moderate"
        case 4: return "Significant"
        default: return "Severe"
        }
    }

    var body: some View {
        NavigationStack {
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

                VStack(spacing: 24) {
                    // Emoji + label
                    VStack(spacing: 8) {
                        Text(severityEmoji)
                            .font(.system(size: 56))
                        Text(severityLabel)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(textDark)
                    }
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.15), value: Int(severity))

                    // Slider
                    VStack(spacing: 8) {
                        Slider(value: $severity, in: 1...5, step: 1)
                            .tint(teal)
                            .padding(.horizontal, 24)

                        HStack {
                            Text("No irritation")
                            Spacer()
                            Text("Severe")
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(textMid)
                        .padding(.horizontal, 24)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(textMid)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("e.g. redness on cheeks after retinol...")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(textMid.opacity(0.6))
                                    .padding(.top, 12)
                                    .padding(.leading, 14)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $notes)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(textDark)
                                .scrollContentBackground(.hidden)
                                .focused($notesFocused)
                                .frame(minHeight: 80, maxHeight: 120)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.88)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)

                    if let error {
                        Text(error)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Log Irritation")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 20).fill(teal))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Log Irritation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(teal)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        error = nil
        do {
            try await service.addIrritationLog(severity: Int(severity), notes: notes)
            onSaved?()
            dismiss()
        } catch {
            self.error = "Couldn't save. Please try again."
        }
        isSaving = false
    }
}
