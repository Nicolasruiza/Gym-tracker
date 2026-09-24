import Foundation

@main
enum CoachEngineChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))!
        func date(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: now)! }
        func workout(_ days: Int, strength: Bool = false, cardio: Bool = false) -> WorkoutRecord {
            WorkoutRecord(id: UUID(), activityName: "Test", startDate: date(days), durationMinutes: 35,
                          sourceName: "Test", isStrength: strength, isCardio: cardio)
        }
        func plan(_ workouts: [WorkoutRecord] = [], sleep: Double = 8,
                  native: [LoggedStrengthSession] = []) -> DailyPlan {
            CoachEngine.makePlan(
                snapshot: HealthSnapshot(workouts: workouts,
                    sleep: SleepSummary(lastNightHours: sleep, sevenDayAverageHours: 8, deepHours: 0, remHours: 0),
                    stepsToday: 0, restingHeartRate: nil, hrvSDNN: nil),
                nextTrainingDay: .legs, profile: .defaultProfile,
                nativeSessions: native, now: now, calendar: calendar)
        }
        func check(_ condition: Bool, _ description: String) {
            precondition(condition, description)
            print("PASS: \(description)")
        }
        check(plan().focus == .strength, "Empty history starts the strength rotation")
        check(plan().cardioTitle == "No cardio planned today", "Strength does not stack cardio")
        check(plan([workout(-1, strength: true)]).focus == .cardio, "Yesterday's strength changes today's focus")
        check(plan([workout(0, strength: true)]).focus == .complete, "Watch strength completes today")
        check(plan(native: [.init(id: UUID(), day: .legs, date: now)]).focus == .complete, "Native strength completes today")
        check(plan([workout(0, cardio: true)]).focus == .complete, "Confirmed cardio completes today")
        check(plan([workout(0)]).focus == .strength, "Unclassified walking is movement")
        check(plan(sleep: 5.5).focus == .recovery, "Low recovery removes formal training")
        check(plan([workout(-1, cardio: true), workout(-2, strength: true), workout(-3, cardio: true)]).focus == .recovery,
              "Three consecutive training days protect recovery")
        check(plan([workout(-8, strength: true), workout(1, strength: true)]).focus == .strength,
              "Old and future workouts do not affect the rolling window")
        let duplicates = [LoggedStrengthSession(id: UUID(), day: .upperA, date: date(-2)),
                          LoggedStrengthSession(id: UUID(), day: .legs, date: date(-4))]
        check(plan([workout(-2, strength: true), workout(-4, strength: true)], native: duplicates).focus == .strength,
              "Watch and native records of the same training days do not double count")
        check(plan([workout(-2, strength: true), workout(-4, strength: true), workout(-6, strength: true)]).focus == .cardio,
              "Three strength days shift the next focus")
        print("12 coach checks passed")
    }
}
