import Foundation

// MARK: - Frequency

enum RoutineFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case everyOtherDay = "every_other_day"
    case twoPerWeek = "2x_week"
    case threePerWeek = "3x_week"

    var label: String {
        switch self {
        case .daily:         return "Daily"
        case .everyOtherDay: return "Every other day"
        case .twoPerWeek:    return "2× per week"
        case .threePerWeek:  return "3× per week"
        }
    }

    var needsDayPicker: Bool { self != .daily }
}

// MARK: - Routine Step

struct RoutineStep: Identifiable, Codable {
    var id: UUID
    var user_id: UUID
    var product_name: String
    var time_of_use: String      // "am", "pm", "both"
    var step_order: Int
    var frequency: String        // RoutineFrequency.rawValue
    var days_of_week: [String]?  // ["mon","tue","wed","thu","fri","sat","sun"] subset; nil = every day
    var created_at: String?

    var frequencyEnum: RoutineFrequency {
        RoutineFrequency(rawValue: frequency) ?? .daily
    }

    var frequencyBadge: String {
        frequencyEnum.label
    }

    var daysDisplay: String {
        guard let days = days_of_week, !days.isEmpty else { return "" }
        return days.map { $0.prefix(1).uppercased() + $0.dropFirst(2) }.joined(separator: ", ")
    }
}

struct NewRoutineStep: Encodable {
    let user_id: UUID
    let product_name: String
    let time_of_use: String
    let step_order: Int
    let frequency: String
    let days_of_week: [String]?
}

// MARK: - Habit Log

struct HabitLog: Identifiable, Codable {
    var id: UUID
    var user_id: UUID
    var log_date: String      // "yyyy-MM-dd"
    var time_of_use: String   // "am" or "pm"
    var completed: Bool
    var completed_at: String?
    var skipped: Bool
    var created_at: String?
}

struct UpsertHabitLog: Encodable {
    let user_id: UUID
    let log_date: String
    let time_of_use: String
    let completed: Bool
    let completed_at: String?
    let skipped: Bool
}

// MARK: - Irritation Log

struct IrritationLog: Identifiable, Codable {
    var id: UUID
    var user_id: UUID
    var log_date: String
    var severity: Int
    var notes: String?
    var created_at: String?
}

struct NewIrritationLog: Encodable {
    let user_id: UUID
    let log_date: String
    let severity: Int
    let notes: String?
}

// MARK: - Progress Photo

struct ProgressPhoto: Identifiable, Codable {
    var id: UUID
    var user_id: UUID
    var photo_url: String
    var captured_at: String
    var notes: String?
    var created_at: String?
}

struct NewProgressPhoto: Encodable {
    let user_id: UUID
    let photo_url: String
    let captured_at: String
    let notes: String?
}

// MARK: - Streak Info

struct StreakInfo {
    let currentStreak: Int
    let longestStreak: Int
    let weeklyCompletionCount: Int  // completed days out of last 7
    let amCompleted: Bool
    let pmCompleted: Bool

    var todayCompleted: Bool { amCompleted && pmCompleted }

    var weeklyPct: Double {
        Double(weeklyCompletionCount) / 7.0
    }
}

// MARK: - Skin Profile

struct SkinProfile {
    let skinType: String
    let concerns: [String]
    let sensitivity: String
    let experience: String

    static let empty = SkinProfile(skinType: "", concerns: [], sensitivity: "", experience: "")
}

// MARK: - Day of week

enum DayOfWeek: String, CaseIterable {
    case mon, tue, wed, thu, fri, sat, sun

    var label: String {
        switch self {
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        case .sun: return "Sun"
        }
    }
}

// MARK: - Date helpers

extension Date {
    var isoDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: self)
    }
}
