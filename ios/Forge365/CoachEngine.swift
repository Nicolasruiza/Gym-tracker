import Foundation

struct NutritionTargets: Hashable {
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let saturatedFatMaxG: Int
    let fiberMinG: Int
    let calibrationSource: String

    var macroLine: String {
        "\(calories) kcal · \(proteinG)P · \(carbsG)C · \(fatG)F"
    }
}

struct NutritionEngine {
    static func makeTargets(bodyWeightKg: Double?, averageDailyEnergyBurned: Double?) -> NutritionTargets? {
        guard let weight = bodyWeightKg, weight >= 40, weight <= 250 else { return nil }

        let calories: Int
        let source: String
        if let expenditure = averageDailyEnergyBurned, expenditure >= 1_400, expenditure <= 6_000 {
            calories = roundTo50(expenditure * 0.95)
            source = "Apple Health 7-day energy estimate · initial calibration"
        } else {
            calories = roundTo50(weight * 28.0)
            source = "Body-weight estimate · initial calibration"
        }

        let protein = Int((weight * 1.8).rounded())
        let fat = Int((weight * 0.8).rounded())
        let remainingCalories = max(400, calories - (protein * 4) - (fat * 9))
        let carbs = Int((Double(remainingCalories) / 4.0).rounded())
        let saturatedFat = max(8, Int(floor((Double(calories) * 0.06) / 9.0)))
        let fiber = max(25, Int((Double(calories) / 1_000.0 * 14.0).rounded()))

        return NutritionTargets(
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            saturatedFatMaxG: saturatedFat,
            fiberMinG: fiber,
            calibrationSource: source
        )
    }

    private static func roundTo50(_ value: Double) -> Int {
        Int((value / 50.0).rounded() * 50.0)
    }
}

struct CoachEngine {
    static func makePlan(
        snapshot: HealthSnapshot,
        nextTrainingDay: TrainingDay,
        profile: CoachProfile,
        liftLog: LiftLogAnalysis? = nil,
        nutrition: NutritionTargets? = nil,
        nativeSessions: [LoggedStrengthSession] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyPlan {
        let sleep = snapshot.sleep
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let workouts = snapshot.workouts.filter { $0.startDate >= cutoff && $0.startDate <= now }
        let cardioMinutes = workouts.filter(\.isCardio).reduce(0) { $0 + $1.durationMinutes }
        // Count strength days across sources so Watch + Forge logs cannot double the quota.
        let strengthDates = workouts.filter(\.isStrength).map(\.startDate)
            + nativeSessions.map(\.date)
            + (liftLog?.sessions.filter { $0.totalLoggedSets > 0 }.map(\.date) ?? [])
        let recentStrength = strengthDates.filter { $0 >= cutoff && $0 <= now }
        let strengthDays = Set(recentStrength.map { calendar.startOfDay(for: $0) })
        let strengthSessions = strengthDays.count
        let formalDates = workouts.filter { $0.isStrength || $0.isCardio }.map(\.startDate) + recentStrength
        let formalDays = Set(formalDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let completedToday = formalDays.contains(today)
        let trainedYesterday = strengthDays.contains(yesterday)
        let consecutiveDays = (1...3).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return formalDays.contains(day)
        }
        let lowRecovery = sleep.lastNightHours > 0 && sleep.lastNightHours < 6.0
        let belowSleepTrend = sleep.sevenDayAverageHours > 0 && sleep.sevenDayAverageHours < 7.0
        let recommendedDay = nextTrainingDay
        let topDeficit = liftLog?.topDeficit

        var trainingTitle = recommendedDay.rawValue
        var trainingDetail: String

        if lowRecovery {
            trainingDetail = "Keep the session conservative today: no PR chasing and no bonus volume. Reassess how you feel during warm-up."
        } else if let deficit = topDeficit {
            let sets = deficit.effectiveSets.formatted(.number.precision(.fractionLength(1)))
            let target = deficit.targetSets.formatted(.number.precision(.fractionLength(0)))
            trainingDetail = "\(deficit.muscle.label) is the biggest weekly gap at \(sets)/\(target) effective sets. Review that gap alongside \(recommendedDay.rawValue)."
        } else if liftLog != nil {
            trainingDetail = "Weekly muscle volume is broadly covered. Continue the rotation with \(recommendedDay.summary.lowercased())."
        } else {
            trainingDetail = recommendedDay.summary + ". Import your Lift Log JSON to let Forge balance this against actual muscle volume."
        }

        var cardioTitle: String
        var cardioDetail: String

        // Planning defaults, not medical targets or a rigid weekly calendar.
        let focus: DailyFocus
        if completedToday {
            focus = .complete
        } else if lowRecovery || consecutiveDays {
            focus = .recovery
        } else if trainedYesterday || strengthSessions >= 3 {
            focus = cardioMinutes < 90 ? .cardio : .recovery
        } else {
            focus = .strength
        }

        switch focus {
        case .strength:
            cardioTitle = "No cardio planned today"
            cardioDetail = "Keep today focused on strength. Your next recommendation adapts to what you actually complete."
        case .cardio:
            trainingTitle = "No weights today"
            trainingDetail = "Your next strength session is \(recommendedDay.rawValue). It stays in the rotation."
            cardioTitle = "Your usual cardio session"
            cardioDetail = "Use your established session within any clinician guidance. No added intensity or catch-up work."
        case .recovery:
            trainingTitle = "Recovery day"
            trainingDetail = "No formal workout today. Your next strength session remains \(recommendedDay.rawValue)."
            cardioTitle = "No cardio planned today"
            cardioDetail = "Everyday movement is enough. Missed sessions are not a debt."
        case .complete:
            trainingTitle = "Training complete"
            trainingDetail = "Today's activity is logged. Your next strength session remains \(recommendedDay.rawValue)."
            cardioTitle = "No extra session today"
            cardioDetail = "Focus on food, normal movement and sleep."
        }

        let sleepTitle: String
        let sleepDetail: String

        if sleep.lastNightHours == 0 {
            sleepTitle = "Sleep data needed"
            sleepDetail = "Wear Apple Watch to sleep and allow Forge to read Sleep from Health."
        } else if belowSleepTrend {
            sleepTitle = "Protect sleep tonight"
            sleepDetail = "Your 7-day average is \(sleep.sevenDayAverageHours.formatted(.number.precision(.fractionLength(1)))) h. Give yourself roughly \(profile.sleepOpportunityTargetHours.formatted(.number.precision(.fractionLength(1)))) h of sleep opportunity tonight."
        } else {
            sleepTitle = "Recovery on track"
            sleepDetail = "Last night: \(sleep.lastNightHours.formatted(.number.precision(.fractionLength(1)))) h · 7-day avg: \(sleep.sevenDayAverageHours.formatted(.number.precision(.fractionLength(1)))) h. Keep the schedule consistent."
        }

        let nutritionTitle: String
        let nutritionDetail: String
        if let nutrition {
            nutritionTitle = nutrition.macroLine
            nutritionDetail = "Protein first; carbs are available to support training, not mandatory or forbidden. Keep saturated fat around ≤\(nutrition.saturatedFatMaxG) g and fiber ≥\(nutrition.fiberMinG) g while Forge calibrates against your real trend."
        } else {
            nutritionTitle = "Nutrition calibration"
            nutritionDetail = "Log body weight in Apple Health so Forge can create the first protein/macro target, then calibrate it from your real trend."
        }

        var reasons = [
            "\(strengthSessions) strength day(s) recorded across Health and Forge over the last 7 days.",
            "\(cardioMinutes) min of aerobic workouts detected over the last 7 days."
        ]

        reasons.append("Initial planning defaults: separate strength and cardio, up to three strength days per rolling week, and recovery after three consecutive training days.")
        reasons.append("The 90-minute cardio comparison is a provisional scheduling rule, not a personal medical target.")
        if let liftLog {
            reasons.append("Lift Log history imported: \(liftLog.sessions.count) session(s) available for training analysis.")
            if let deficit = topDeficit {
                reasons.append("Largest muscle-volume gap: \(deficit.muscle.label) at \(deficit.effectiveSets.formatted(.number.precision(.fractionLength(1)))) / \(deficit.targetSets.formatted(.number.precision(.fractionLength(0)))) effective sets this week.")
            }
        }
        if let nutrition {
            reasons.append("Nutrition starts from \(nutrition.calibrationSource.lowercased()) and is meant to be corrected by weight/waist/performance trends.")
        }
        if sleep.lastNightHours > 0 {
            reasons.append("Last-night sleep: \(sleep.lastNightHours.formatted(.number.precision(.fractionLength(1)))) h; 7-day average: \(sleep.sevenDayAverageHours.formatted(.number.precision(.fractionLength(1)))) h.")
        }
        if profile.avoidsHIIT {
            reasons.append("HIIT is excluded from Forge recommendations by preference.")
        }
        if profile.cardiacMode == .pendingCardiologyReview {
            reasons.append("Cardiology guidance is pending, so Forge does not invent heart-rate limits or prescribe maximal-intensity work.")
        }

        let message = focus == .strength
            ? "One focus today: complete your strength session. Cardio can have its own day."
            : trainingDetail

        return DailyPlan(
            focus: focus,
            trainingTitle: trainingTitle,
            trainingDetail: trainingDetail,
            cardioTitle: cardioTitle,
            cardioDetail: cardioDetail,
            sleepTitle: sleepTitle,
            sleepDetail: sleepDetail,
            nutritionTitle: nutritionTitle,
            nutritionDetail: nutritionDetail,
            coachMessage: message,
            reasons: reasons
        )
    }
}
