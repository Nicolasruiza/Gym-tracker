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
        nutrition: NutritionTargets? = nil
    ) -> DailyPlan {
        let sleep = snapshot.sleep
        let cardioMinutes = snapshot.cardioMinutesLast7Days
        let strengthSessions = snapshot.strengthSessionsLast7Days
        let lowRecovery = sleep.lastNightHours > 0 && sleep.lastNightHours < 6.0
        let belowSleepTrend = sleep.sevenDayAverageHours > 0 && sleep.sevenDayAverageHours < 7.0
        let recommendedDay = nextTrainingDay
        let topDeficit = liftLog?.topDeficit

        let trainingTitle = recommendedDay.rawValue
        let trainingDetail: String

        if lowRecovery {
            trainingDetail = "Keep the session conservative today: no PR chasing and no bonus volume. Reassess how you feel during warm-up."
        } else if let deficit = topDeficit {
            let sets = deficit.effectiveSets.formatted(.number.precision(.fractionLength(1)))
            let target = deficit.targetSets.formatted(.number.precision(.fractionLength(0)))
            trainingDetail = "\(deficit.muscle.label) is the biggest weekly gap at \(sets)/\(target) effective sets. Forge uses that gap to shape exercise priority inside \(recommendedDay.rawValue)."
        } else if liftLog != nil {
            trainingDetail = "Weekly muscle volume is broadly covered. Continue the rotation with \(recommendedDay.summary.lowercased())."
        } else {
            trainingDetail = recommendedDay.summary + ". Import your Lift Log JSON to let Forge balance this against actual muscle volume."
        }

        let cardioTitle: String
        let cardioDetail: String

        if lowRecovery {
            cardioTitle = "No extra cardio required"
            cardioDetail = "Recovery is the priority today. Normal daily movement is enough."
        } else if cardioMinutes < 90 {
            cardioTitle = "Usual incline walk"
            cardioDetail = "20–30 min at the comfortable/moderate effort you already tolerate. Forge won't prescribe HR ceilings or hard intervals while cardiology review is pending."
        } else {
            cardioTitle = "Cardio optional"
            cardioDetail = "You already logged \(cardioMinutes) min of aerobic workouts in the last 7 days. Strength and normal movement can take priority today."
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
            "\(strengthSessions) strength workout(s) detected in Health over the last 7 days.",
            "\(cardioMinutes) min of aerobic workouts detected over the last 7 days."
        ]

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

        let message: String
        if lowRecovery {
            message = "Today's plan protects recovery without throwing away the week. Do the planned strength session only if warm-up feels normal; skip extra conditioning."
        } else if let deficit = topDeficit {
            message = "Today is being shaped by what your week actually lacks: \(deficit.muscle.label.lowercased()) needs the most attention right now."
        } else if cardioMinutes < 90 {
            message = "Strength stays the anchor today, with a short incline walk available to fill the aerobic side of the week."
        } else {
            message = "Your aerobic work is already building. Today can stay focused on the next strength session and sleep consistency."
        }

        return DailyPlan(
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
