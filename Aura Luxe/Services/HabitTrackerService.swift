import Foundation
import Supabase
import UIKit

struct HabitTrackerService {
    private let client = SupabaseManage.shared.client

    // MARK: - Auth

    func authenticatedUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Skin Profile (from onboarding quiz)

    func loadSkinProfile() async throws -> SkinProfile {
        let userID = try await authenticatedUserID()
        let response = try await client
            .from("onboarding_quiz_responses")
            .select("skin_after_cleansing,oiliness_during_day,sensitivity_level,concerns,routine_level")
            .eq("user_id", value: userID.uuidString)
            .single()
            .execute()

        let row = try JSONDecoder().decode(QuizProfileRow.self, from: response.data)
        return row.toSkinProfile()
    }

    // MARK: - Routine Steps

    func fetchRoutineSteps() async throws -> [RoutineStep] {
        let userID = try await authenticatedUserID()
        let response = try await client
            .from("routine_steps")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("step_order")
            .execute()
        return try JSONDecoder().decode([RoutineStep].self, from: response.data)
    }

    func addRoutineStep(productName: String, timeOfUse: String, frequency: RoutineFrequency, daysOfWeek: [String]?, existingCount: Int) async throws -> RoutineStep {
        let userID = try await authenticatedUserID()
        let new = NewRoutineStep(
            user_id: userID,
            product_name: productName,
            time_of_use: timeOfUse,
            step_order: existingCount,
            frequency: frequency.rawValue,
            days_of_week: daysOfWeek
        )
        let response = try await client
            .from("routine_steps")
            .insert(new)
            .select()
            .single()
            .execute()
        return try JSONDecoder().decode(RoutineStep.self, from: response.data)
    }

    func deleteRoutineStep(id: UUID) async throws {
        try await client
            .from("routine_steps")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateStepOrder(steps: [RoutineStep]) async throws {
        for (index, step) in steps.enumerated() {
            try await client
                .from("routine_steps")
                .update(["step_order": index])
                .eq("id", value: step.id.uuidString)
                .execute()
        }
    }

    // MARK: - Migration from skincare_routine

    func migrateFromLegacyRoutineIfNeeded() async {
        guard let userID = try? await authenticatedUserID() else { return }
        do {
            let legacyResponse = try await client
                .from("skincare_routine")
                .select()
                .eq("user_id", value: userID.uuidString)
                .execute()
            let legacy = try JSONDecoder().decode([LegacyRoutineEntry].self, from: legacyResponse.data)
            guard !legacy.isEmpty else { return }

            for (index, entry) in legacy.enumerated() {
                let mapped = timeOfUseMigrated(entry.time_of_use)
                let new = NewRoutineStep(
                    user_id: userID,
                    product_name: entry.product_name,
                    time_of_use: mapped,
                    step_order: index,
                    frequency: RoutineFrequency.daily.rawValue,
                    days_of_week: nil
                )
                try await client.from("routine_steps").upsert(new).execute()
            }
            try await client
                .from("skincare_routine")
                .delete()
                .eq("user_id", value: userID.uuidString)
                .execute()
        } catch {
            // migration failure is non-critical; new routine is empty
        }
    }

    private func timeOfUseMigrated(_ raw: String) -> String {
        switch raw.lowercased() {
        case "morning": return "am"
        case "night":   return "pm"
        default:        return raw  // "both", "am", "pm" pass through
        }
    }

    // MARK: - Habit Logs

    func fetchHabitLogs(for date: Date) async throws -> [HabitLog] {
        let userID = try await authenticatedUserID()
        let response = try await client
            .from("habit_logs")
            .select()
            .eq("user_id", value: userID.uuidString)
            .eq("log_date", value: date.isoDateString)
            .execute()
        return try JSONDecoder().decode([HabitLog].self, from: response.data)
    }

    func markCompleted(date: Date, timeOfUse: String) async throws {
        let userID = try await authenticatedUserID()
        let now = ISO8601DateFormatter().string(from: Date())
        let log = UpsertHabitLog(
            user_id: userID,
            log_date: date.isoDateString,
            time_of_use: timeOfUse,
            completed: true,
            completed_at: now,
            skipped: false
        )
        try await client.from("habit_logs").upsert(log).execute()
    }

    func markSkipped(date: Date, timeOfUse: String) async throws {
        let userID = try await authenticatedUserID()
        let log = UpsertHabitLog(
            user_id: userID,
            log_date: date.isoDateString,
            time_of_use: timeOfUse,
            completed: false,
            completed_at: nil,
            skipped: true
        )
        try await client.from("habit_logs").upsert(log).execute()
    }

    func markUncompleted(date: Date, timeOfUse: String) async throws {
        let userID = try await authenticatedUserID()
        let log = UpsertHabitLog(
            user_id: userID,
            log_date: date.isoDateString,
            time_of_use: timeOfUse,
            completed: false,
            completed_at: nil,
            skipped: false
        )
        try await client.from("habit_logs").upsert(log).execute()
    }

    // MARK: - Streak Computation

    func computeStreak(for date: Date) async throws -> StreakInfo {
        let userID = try await authenticatedUserID()
        // Fetch last 90 days of logs
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date
        let response = try await client
            .from("habit_logs")
            .select()
            .eq("user_id", value: userID.uuidString)
            .gte("log_date", value: cutoff.isoDateString)
            .execute()
        let logs = try JSONDecoder().decode([HabitLog].self, from: response.data)

        // Group by date
        var byDate: [String: [HabitLog]] = [:]
        for log in logs {
            byDate[log.log_date, default: []].append(log)
        }

        // Determine if both AM and PM completed for a given date string
        func dayCompleted(_ dateStr: String) -> Bool {
            let dayLogs = byDate[dateStr] ?? []
            let amDone = dayLogs.first(where: { $0.time_of_use == "am" })?.completed == true
            let pmDone = dayLogs.first(where: { $0.time_of_use == "pm" })?.completed == true
            return amDone && pmDone
        }

        // Today's individual completions
        let todayStr = date.isoDateString
        let todayLogs = byDate[todayStr] ?? []
        let amCompleted = todayLogs.first(where: { $0.time_of_use == "am" })?.completed == true
        let pmCompleted = todayLogs.first(where: { $0.time_of_use == "pm" })?.completed == true

        // Current streak — count backwards from yesterday (today doesn't break streak until end of day)
        var currentStreak = 0
        var checkDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        for _ in 0..<90 {
            if dayCompleted(checkDate.isoDateString) {
                currentStreak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        if amCompleted && pmCompleted { currentStreak += 1 }  // count today if fully done

        // Longest streak
        var longestStreak = 0
        var runningStreak = 0
        var scanDate = cutoff
        while scanDate <= date {
            if dayCompleted(scanDate.isoDateString) {
                runningStreak += 1
                longestStreak = max(longestStreak, runningStreak)
            } else {
                runningStreak = 0
            }
            scanDate = Calendar.current.date(byAdding: .day, value: 1, to: scanDate) ?? scanDate
        }

        // Weekly completion (last 7 days including today)
        var weeklyCount = 0
        for i in 0..<7 {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: date) ?? date
            if dayCompleted(d.isoDateString) { weeklyCount += 1 }
        }

        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            weeklyCompletionCount: weeklyCount,
            amCompleted: amCompleted,
            pmCompleted: pmCompleted
        )
    }

    // MARK: - Irritation Logs

    func addIrritationLog(severity: Int, notes: String?) async throws {
        let userID = try await authenticatedUserID()
        let log = NewIrritationLog(
            user_id: userID,
            log_date: Date().isoDateString,
            severity: severity,
            notes: notes?.isEmpty == true ? nil : notes
        )
        try await client.from("irritation_logs").insert(log).execute()
    }

    func fetchRecentIrritationLogs(limit: Int = 10) async throws -> [IrritationLog] {
        let userID = try await authenticatedUserID()
        let response = try await client
            .from("irritation_logs")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("log_date", ascending: false)
            .limit(limit)
            .execute()
        return try JSONDecoder().decode([IrritationLog].self, from: response.data)
    }

    // MARK: - Progress Photos

    func uploadProgressPhoto(imageData: Data, notes: String?) async throws -> ProgressPhoto {
        let userID = try await authenticatedUserID()
        let fileName = "\(userID.uuidString)/\(UUID().uuidString).jpg"

        try await client.storage
            .from("progress-photos")
            .upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg"))

        let publicURL = try client.storage
            .from("progress-photos")
            .getPublicURL(path: fileName)

        let new = NewProgressPhoto(
            user_id: userID,
            photo_url: publicURL.absoluteString,
            captured_at: Date().isoDateString,
            notes: notes?.isEmpty == true ? nil : notes
        )
        let response = try await client
            .from("progress_photos")
            .insert(new)
            .select()
            .single()
            .execute()
        return try JSONDecoder().decode(ProgressPhoto.self, from: response.data)
    }

    func fetchProgressPhotos() async throws -> [ProgressPhoto] {
        let userID = try await authenticatedUserID()
        let response = try await client
            .from("progress_photos")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("captured_at", ascending: false)
            .execute()
        return try JSONDecoder().decode([ProgressPhoto].self, from: response.data)
    }

    // MARK: - Conflict Detection for Full Routine

    func detectRoutineConflicts(steps: [RoutineStep]) async -> [IngredientConflict] {
        guard !steps.isEmpty else { return [] }
        let names = steps.map(\.product_name)
        var allIngredients: [String] = []

        if let response = try? await client
            .from("products")
            .select("ingredients")
            .in("name", values: names)
            .execute(),
           let rows = try? JSONDecoder().decode([ProductIngredientsRow].self, from: response.data) {
            for row in rows {
                allIngredients.append(contentsOf: row.ingredients)
            }
        }

        // Also include product names themselves as pseudo-ingredient keywords
        allIngredients.append(contentsOf: names)

        guard allIngredients.count >= 2 else { return [] }
        let service = ConflictDetectionService()
        return service.detect(ingredientsA: allIngredients, ingredientsB: allIngredients)
    }

    // MARK: - Today's progress

    func todayCompletionPct(steps: [RoutineStep], logs: [HabitLog], date: Date) -> Double {
        let scheduled = stepsScheduledToday(steps: steps, date: date)
        guard !scheduled.isEmpty else { return 0 }
        let amNeeded = scheduled.contains { $0.time_of_use == "am" || $0.time_of_use == "both" }
        let pmNeeded = scheduled.contains { $0.time_of_use == "pm" || $0.time_of_use == "both" }
        var completed = 0
        var total = 0
        if amNeeded {
            total += 1
            if logs.first(where: { $0.time_of_use == "am" })?.completed == true { completed += 1 }
        }
        if pmNeeded {
            total += 1
            if logs.first(where: { $0.time_of_use == "pm" })?.completed == true { completed += 1 }
        }
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    func stepsScheduledToday(steps: [RoutineStep], date: Date) -> [RoutineStep] {
        let weekday = Calendar.current.component(.weekday, from: date)
        let dayKey: String
        switch weekday {
        case 1: dayKey = "sun"
        case 2: dayKey = "mon"
        case 3: dayKey = "tue"
        case 4: dayKey = "wed"
        case 5: dayKey = "thu"
        case 6: dayKey = "fri"
        default: dayKey = "sat"
        }

        return steps.filter { step in
            guard let days = step.days_of_week, !days.isEmpty else { return true }
            return days.contains(dayKey)
        }
    }
}

// MARK: - Private Decodable Helpers

private struct QuizProfileRow: Decodable {
    let skin_after_cleansing: String
    let oiliness_during_day: String
    let sensitivity_level: String
    let concerns: [String]
    let routine_level: String

    func toSkinProfile() -> SkinProfile {
        let skinType: String
        switch skin_after_cleansing {
        case "Tight and dry":    skinType = "Dry"
        case "Oily all over":    skinType = "Oily"
        case "Combination":      skinType = "Combination"
        default:                 skinType = "Normal"
        }

        let sensitivity: String
        switch sensitivity_level {
        case "Very sensitive":   sensitivity = "High"
        case "Slightly sensitive": sensitivity = "Medium"
        default:                 sensitivity = "Low"
        }

        let experience: String
        switch routine_level {
        case "Beginner":         experience = "Beginner"
        case "I have a routine": experience = "Intermediate"
        default:                 experience = "Advanced"
        }

        return SkinProfile(
            skinType: skinType,
            concerns: concerns,
            sensitivity: sensitivity,
            experience: experience
        )
    }
}

private struct LegacyRoutineEntry: Decodable {
    let product_name: String
    let time_of_use: String
}

private struct ProductIngredientsRow: Decodable {
    let ingredients: [String]
}
