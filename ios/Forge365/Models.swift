import Foundation

struct WorkoutRecord: Identifiable, Hashable {
    let id: UUID
    let activityName: String
    let startDate: Date
    let durationMinutes: Int
    let sourceName: String
    let isStrength: Bool
    let isCardio: Bool
}

struct SleepSummary: Hashable {
    var lastNightHours: Double
    var sevenDayAverageHours: Double
    var deepHours: Double
    var remHours: Double

    static let empty = SleepSummary(lastNightHours: 0, sevenDayAverageHours: 0, deepHours: 0, remHours: 0)
}

struct HealthSnapshot: Hashable {
    var workouts: [WorkoutRecord]
    var sleep: SleepSummary
    var stepsToday: Int
    var restingHeartRate: Double?
    var hrvSDNN: Double?

    static let empty = HealthSnapshot(workouts: [], sleep: .empty, stepsToday: 0, restingHeartRate: nil, hrvSDNN: nil)

    var cardioMinutesLast7Days: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return workouts
            .filter { $0.isCardio && $0.startDate >= cutoff }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var strengthSessionsLast7Days: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return workouts.filter { $0.isStrength && $0.startDate >= cutoff }.count
    }
}

enum CardiacMode: String, Codable {
    case pendingCardiologyReview
    case clinicianGuidanceAvailable
}

enum TrainingDay: String, CaseIterable, Codable, Identifiable {
    case upperA = "Upper A"
    case legs = "Legs"
    case upperB = "Upper B"

    var id: String { rawValue }

    var next: TrainingDay {
        switch self {
        case .upperA: return .legs
        case .legs: return .upperB
        case .upperB: return .upperA
        }
    }

    var summary: String {
        switch self {
        case .upperA: return "Chest · back · shoulders · arms"
        case .legs: return "Quads · hamstrings · glutes · calves · core"
        case .upperB: return "Back priority · chest · shoulders · arms"
        }
    }
}

struct DailyPlan: Hashable {
    let trainingTitle: String
    let trainingDetail: String
    let cardioTitle: String
    let cardioDetail: String
    let sleepTitle: String
    let sleepDetail: String
    let nutritionTitle: String
    let nutritionDetail: String
    let coachMessage: String
    let reasons: [String]
}

struct CoachProfile: Codable, Hashable {
    var cardiacMode: CardiacMode = .pendingCardiologyReview
    var avoidsHIIT: Bool = true
    var sleepOpportunityTargetHours: Double = 8.0

    static let defaultProfile = CoachProfile()
}

struct LoggedStrengthSession: Codable, Hashable, Identifiable {
    let id: UUID
    let day: TrainingDay
    let date: Date
}
