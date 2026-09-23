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

    init?(liftLogDay: Int) {
        switch liftLogDay {
        case 1: self = .upperA
        case 2: self = .legs
        case 3: self = .upperB
        default: return nil
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

// MARK: - Lift Log import + muscle-volume model

enum MuscleGroup: String, CaseIterable, Codable, Hashable, Identifiable {
    case chest, back, shoulders, arms, glutes, hamstrings, quads, calves, core

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .glutes: return "Glutes"
        case .hamstrings: return "Hamstrings"
        case .quads: return "Quads"
        case .calves: return "Calves"
        case .core: return "Core"
        }
    }

    var isLowerBody: Bool {
        switch self {
        case .glutes, .hamstrings, .quads, .calves: return true
        default: return false
        }
    }
}

struct MuscleVolume: Hashable, Identifiable {
    let muscle: MuscleGroup
    let effectiveSets: Double
    let targetSets: Double

    var id: MuscleGroup { muscle }
    var deficit: Double { max(0, targetSets - effectiveSets) }
    var completion: Double { targetSets > 0 ? min(1.5, effectiveSets / targetSets) : 0 }
}

struct LiftLogSessionSummary: Hashable, Identifiable {
    let id: UUID
    let date: Date
    let day: TrainingDay
    let exerciseCount: Int
    let totalLoggedSets: Int
}

struct LiftLogAnalysis: Hashable {
    let profileName: String?
    let sessions: [LiftLogSessionSummary]
    let weeklyVolume: [MuscleVolume]
    let importedAt: Date

    var lastSession: LiftLogSessionSummary? {
        sessions.max(by: { $0.date < $1.date })
    }

    var topDeficit: MuscleVolume? {
        weeklyVolume
            .filter { $0.deficit > 0.5 }
            .max(by: { $0.deficit < $1.deficit })
    }

    var recommendedNextDay: TrainingDay? {
        guard let topDeficit else { return lastSession?.day.next }
        if topDeficit.muscle.isLowerBody && topDeficit.deficit >= 2 {
            return .legs
        }

        guard !topDeficit.muscle.isLowerBody else { return lastSession?.day.next }
        if lastSession?.day == .upperB { return .upperA }
        return .upperB
    }
}

enum LiftLogImportError: LocalizedError {
    case invalidJSON
    case missingHistory

    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "That file isn't a valid Lift Log JSON export."
        case .missingHistory: return "The JSON is valid, but it doesn't contain Lift Log history."
        }
    }
}

struct LiftLogImporter {
    private struct Credit {
        let primary: [MuscleGroup]
        let secondary: [MuscleGroup]
    }

    // Mirrors the movement metadata already used by Lift Log on the web.
    // A completed set gives 1.0 credit to a primary muscle and 0.5 to a secondary one.
    private static let credits: [String: Credit] = {
        var map: [String: Credit] = [:]
        func add(_ ids: [String], primary: [MuscleGroup], secondary: [MuscleGroup] = []) {
            for id in ids { map[id] = Credit(primary: primary, secondary: secondary) }
        }

        add(["leg_raise", "cbl_crunch"], primary: [.core])
        add(["plank", "pallof", "sa_dead_bug", "sa_side_plank", "sa_pallof"], primary: [.core])

        add(["bb_press", "sa_db_bench", "alt_db_bench", "alt_machine_press"], primary: [.chest], secondary: [.arms, .shoulders])
        add(["db_incl", "sa_db_incl", "alt_incline_machine", "alt_incline_bb"], primary: [.chest], secondary: [.arms, .shoulders])
        add(["m_fly", "sa_m_fly", "fx_cable_fly", "fx_m_fly2", "alt_cable_fly", "alt_db_fly"], primary: [.chest])

        add(["db_ohp", "sa_db_ohp", "sa_landmine", "alt_machine_ohp", "alt_landmine"], primary: [.shoulders], secondary: [.arms])
        add(["lat_raise", "sa_lat_raise", "fx_cable_lat", "alt_cable_lat_raise", "alt_machine_lat_raise"], primary: [.shoulders])
        add(["face_pull", "sa_face_pull", "fx_pull_apart", "alt_rear_delt_fly", "alt_pull_apart"], primary: [.shoulders], secondary: [.back])

        add(["lat_pull", "sa_lat_pull", "sa_pulldown2", "pullup", "alt_neutral_pulldown", "alt_assist_pullup", "alt_inverted_row", "alt_assist_pullup2"], primary: [.back], secondary: [.arms])
        add(["db_row", "cbl_row", "sa_cbl_row", "sa_cs_row", "fx_cs_row", "fx_pullover", "alt_cs_row", "alt_row_1arm"], primary: [.back], secondary: [.arms])

        add(["cbl_tri", "skull", "sa_cbl_tri", "sa_rope_tri", "alt_rope_tri", "alt_oh_tri"], primary: [.arms])
        add(["db_curl", "bb_curl", "hammer", "sa_db_curl", "sa_hammer", "fx_incline_curl", "alt_cable_curl", "alt_ez_curl"], primary: [.arms])

        add(["gob_squat", "sa_gob_squat", "alt_hack_squat", "alt_split_squat"], primary: [.quads, .glutes], secondary: [.core])
        add(["leg_press", "sa_leg_press", "alt_hack_squat2", "alt_single_leg_press"], primary: [.quads, .glutes])
        add(["rdl", "sa_rdl", "fx_back_ext", "alt_db_rdl", "alt_back_ext"], primary: [.hamstrings, .glutes], secondary: [.back])
        add(["sa_hip_thrust", "fx_hip_thrust", "alt_single_thrust", "alt_glute_bridge"], primary: [.glutes], secondary: [.hamstrings])
        add(["sa_glute_bridge", "fx_kickback", "alt_abductor"], primary: [.glutes])
        add(["ham_curl", "sa_ham_curl", "fx_seated_ham", "alt_seated_ham", "alt_nordic"], primary: [.hamstrings])
        add(["leg_ext", "sa_leg_ext", "alt_sissy"], primary: [.quads])
        add(["calf", "sa_calf", "alt_seated_calf"], primary: [.calves])
        return map
    }()

    private static let targets: [MuscleGroup: Double] = [
        .chest: 12,
        .back: 12,
        .shoulders: 12,
        .arms: 12,
        .glutes: 12,
        .hamstrings: 10,
        .quads: 10,
        .calves: 8,
        .core: 10
    ]

    static func parse(data: Data, now: Date = Date()) throws -> LiftLogAnalysis {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LiftLogImportError.invalidJSON
        }
        guard let history = root["history"] as? [[String: Any]] else {
            throw LiftLogImportError.missingHistory
        }

        let profileName = root["profileName"] as? String
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"

        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        var volumes = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 0.0) })
        var summaries: [LiftLogSessionSummary] = []

        for rawSession in history {
            guard let dateString = rawSession["date"] as? String,
                  let date = formatter.date(from: dateString),
                  let rawDay = rawSession["day"] as? NSNumber,
                  let day = TrainingDay(liftLogDay: rawDay.intValue) else {
                continue
            }

            let entries = rawSession["entries"] as? [String: Any] ?? [:]
            var sessionSets = 0

            for (exerciseID, rawEntry) in entries {
                guard let entry = rawEntry as? [String: Any] else { continue }
                let reps = entry["reps"] as? [Any] ?? []
                let sets = reps.count
                guard sets > 0 else { continue }
                sessionSets += sets

                guard date >= cutoff, let credit = credits[exerciseID] else { continue }
                let setCount = Double(sets)
                for muscle in credit.primary { volumes[muscle, default: 0] += setCount }
                for muscle in credit.secondary { volumes[muscle, default: 0] += setCount * 0.5 }
            }

            summaries.append(
                LiftLogSessionSummary(
                    id: UUID(),
                    date: date,
                    day: day,
                    exerciseCount: entries.count,
                    totalLoggedSets: sessionSets
                )
            )
        }

        let weekly = MuscleGroup.allCases.map { muscle in
            MuscleVolume(
                muscle: muscle,
                effectiveSets: volumes[muscle, default: 0],
                targetSets: targets[muscle, default: 10]
            )
        }

        return LiftLogAnalysis(
            profileName: profileName,
            sessions: summaries.sorted(by: { $0.date > $1.date }),
            weeklyVolume: weekly,
            importedAt: now
        )
    }
}
