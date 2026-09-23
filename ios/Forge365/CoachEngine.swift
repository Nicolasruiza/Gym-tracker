import Foundation

struct CoachEngine {
    static func makePlan(
        snapshot: HealthSnapshot,
        nextTrainingDay: TrainingDay,
        profile: CoachProfile
    ) -> DailyPlan {
        let sleep = snapshot.sleep
        let cardioMinutes = snapshot.cardioMinutesLast7Days
        let strengthSessions = snapshot.strengthSessionsLast7Days
        let lowRecovery = sleep.lastNightHours > 0 && sleep.lastNightHours < 6.0
        let belowSleepTrend = sleep.sevenDayAverageHours > 0 && sleep.sevenDayAverageHours < 7.0

        let trainingTitle: String
        let trainingDetail: String

        if lowRecovery {
            trainingTitle = nextTrainingDay.rawValue
            trainingDetail = "Keep the session, but don't chase PRs or add bonus volume today. Reassess how you feel during warm-up."
        } else {
            trainingTitle = nextTrainingDay.rawValue
            trainingDetail = nextTrainingDay.summary + ". Continue the Lift Log rotation; detailed muscle-volume balancing comes next when legacy set history is imported."
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

        let nutritionTitle = "Nutrition calibration"
        let nutritionDetail = "Next slice: calorie/protein baseline, carbs matched to training demand, meal suggestions, and weekly adjustment from weight + waist + performance."

        var reasons = [
            "\(strengthSessions) strength workout(s) detected in Health over the last 7 days.",
            "\(cardioMinutes) min of aerobic workouts detected over the last 7 days."
        ]

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
