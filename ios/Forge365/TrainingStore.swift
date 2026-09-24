import Foundation
import Combine

struct ForgeExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let targetReps: Int
    let startingWeight: Double
    let increment: Double
}

enum ForgeWorkoutPlan {
    static func exercises(for day: TrainingDay) -> [ForgeExercise] {
        switch day {
        case .upperA:
            return [
                .init(id: "leg_raise", name: "Hanging leg raise", targetReps: 10, startingWeight: 0, increment: 0),
                .init(id: "pallof", name: "Pallof press (per side)", targetReps: 12, startingWeight: 30, increment: 5),
                .init(id: "bb_press", name: "Barbell press", targetReps: 6, startingWeight: 135, increment: 5),
                .init(id: "lat_pull", name: "Lat pulldown", targetReps: 8, startingWeight: 75, increment: 5),
                .init(id: "db_ohp", name: "Dumbbell shoulder press", targetReps: 8, startingWeight: 35, increment: 5),
                .init(id: "db_row", name: "Dumbbell row", targetReps: 8, startingWeight: 50, increment: 5),
                .init(id: "m_fly", name: "Machine fly", targetReps: 12, startingWeight: 145, increment: 5),
                .init(id: "cbl_tri", name: "Cable triceps extension", targetReps: 12, startingWeight: 60, increment: 5),
                .init(id: "db_curl", name: "Dumbbell bicep curl", targetReps: 12, startingWeight: 30, increment: 5),
                .init(id: "face_pull", name: "Face pull", targetReps: 15, startingWeight: 30, increment: 5)
            ]
        case .legs:
            return [
                .init(id: "plank", name: "Plank (seconds)", targetReps: 45, startingWeight: 0, increment: 0),
                .init(id: "gob_squat", name: "Goblet squat", targetReps: 8, startingWeight: 50, increment: 5),
                .init(id: "rdl", name: "Romanian deadlift", targetReps: 6, startingWeight: 95, increment: 10),
                .init(id: "leg_press", name: "Leg press", targetReps: 10, startingWeight: 180, increment: 10),
                .init(id: "ham_curl", name: "Lying hamstring curl", targetReps: 12, startingWeight: 80, increment: 10),
                .init(id: "leg_ext", name: "Leg extension", targetReps: 12, startingWeight: 100, increment: 10),
                .init(id: "calf", name: "Calf raise", targetReps: 15, startingWeight: 90, increment: 10)
            ]
        case .upperB:
            return [
                .init(id: "cbl_crunch", name: "Cable crunch", targetReps: 15, startingWeight: 50, increment: 5),
                .init(id: "db_incl", name: "Dumbbell incline bench press", targetReps: 8, startingWeight: 45, increment: 5),
                .init(id: "pullup", name: "Pull-ups", targetReps: 8, startingWeight: 0, increment: 0),
                .init(id: "cbl_row", name: "Cable row", targetReps: 10, startingWeight: 70, increment: 5),
                .init(id: "bb_curl", name: "Barbell curl", targetReps: 8, startingWeight: 70, increment: 5),
                .init(id: "lat_raise", name: "Lateral raise", targetReps: 15, startingWeight: 15, increment: 5),
                .init(id: "skull", name: "Skull crusher", targetReps: 12, startingWeight: 40, increment: 5),
                .init(id: "hammer", name: "Hammer curls", targetReps: 12, startingWeight: 25, increment: 5)
            ]
        }
    }

    static func definition(id: String, day: TrainingDay) -> ForgeExercise? {
        exercises(for: day).first(where: { $0.id == id })
    }
}

struct WorkoutExerciseState: Codable, Hashable, Identifiable {
    let id: String
    var weight: Double
    var reps: [Int]
}

struct ActiveStrengthWorkout: Codable, Hashable {
    let id: UUID
    let day: TrainingDay
    let started: Date
    var exercises: [WorkoutExerciseState]
}

struct DetailedStrengthSession: Codable, Hashable, Identifiable {
    let id: UUID
    let day: TrainingDay
    let date: Date
    let exercises: [WorkoutExerciseState]
}

struct LiftLogWeightImporter {
    static func nextWeights(from data: Data) -> [String: Double] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["next"] as? [String: Any] else {
            return [:]
        }

        var weights: [String: Double] = [:]
        for (id, value) in raw {
            if let number = value as? NSNumber {
                weights[id] = number.doubleValue
            }
        }
        return weights
    }
}

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var sessions: [LoggedStrengthSession] = []
    @Published private(set) var detailedSessions: [DetailedStrengthSession] = []
    @Published private(set) var nextDay: TrainingDay = .upperA
    @Published private(set) var nextWeights: [String: Double] = [:]
    @Published private(set) var activeWorkout: ActiveStrengthWorkout?

    private let sessionsKey = "forge365.strengthSessions"
    private let detailedSessionsKey = "forge365.detailedStrengthSessions"
    private let nextDayKey = "forge365.nextTrainingDay"
    private let nextWeightsKey = "forge365.nextWeights"
    private let activeWorkoutKey = "forge365.activeWorkout"

    init() {
        load()
    }

    var activeDefinitions: [ForgeExercise] {
        guard let activeWorkout else { return [] }
        return ForgeWorkoutPlan.exercises(for: activeWorkout.day)
    }

    var canFinishActiveWorkout: Bool {
        guard let activeWorkout else { return false }
        return !activeWorkout.exercises.isEmpty && activeWorkout.exercises.allSatisfy { state in
            state.reps.count == 3 && state.reps.allSatisfy { $0 > 0 }
        }
    }

    func startWorkout(day: TrainingDay) {
        guard activeWorkout == nil else { return }
        let definitions = ForgeWorkoutPlan.exercises(for: day)
        let states = definitions.map { exercise in
            WorkoutExerciseState(
                id: exercise.id,
                weight: nextWeights[exercise.id] ?? exercise.startingWeight,
                reps: [0, 0, 0]
            )
        }
        activeWorkout = ActiveStrengthWorkout(id: UUID(), day: day, started: Date(), exercises: states)
        persist()
    }

    func weight(for exerciseID: String) -> Double {
        activeWorkout?.exercises.first(where: { $0.id == exerciseID })?.weight ?? 0
    }

    func rep(for exerciseID: String, setIndex: Int) -> Int {
        guard let state = activeWorkout?.exercises.first(where: { $0.id == exerciseID }),
              state.reps.indices.contains(setIndex) else { return 0 }
        return state.reps[setIndex]
    }

    func setWeight(_ value: Double, for exerciseID: String) {
        guard var active = activeWorkout,
              let index = active.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        active.exercises[index].weight = max(0, value)
        activeWorkout = active
        persist()
    }

    func setRep(_ value: Int, for exerciseID: String, setIndex: Int) {
        guard var active = activeWorkout,
              let index = active.exercises.firstIndex(where: { $0.id == exerciseID }),
              active.exercises[index].reps.indices.contains(setIndex) else { return }
        active.exercises[index].reps[setIndex] = max(0, value)
        activeWorkout = active
        persist()
    }

    func finishActiveWorkout() {
        guard let active = activeWorkout, canFinishActiveWorkout else { return }

        for state in active.exercises {
            guard let definition = ForgeWorkoutPlan.definition(id: state.id, day: active.day) else { continue }
            let hitTarget = state.reps.allSatisfy { $0 >= definition.targetReps }
            if hitTarget && definition.increment > 0 {
                nextWeights[state.id] = state.weight + definition.increment
            } else {
                nextWeights[state.id] = state.weight
            }
        }

        detailedSessions.append(
            DetailedStrengthSession(id: active.id, day: active.day, date: Date(), exercises: active.exercises)
        )
        detailedSessions = Array(detailedSessions.suffix(100))
        sessions.append(LoggedStrengthSession(id: active.id, day: active.day, date: Date()))
        sessions = Array(sessions.suffix(100))
        nextDay = active.day.next
        activeWorkout = nil
        persist()
    }

    func cancelActiveWorkout() {
        activeWorkout = nil
        persist()
    }

    func complete(_ day: TrainingDay) {
        sessions.append(LoggedStrengthSession(id: UUID(), day: day, date: Date()))
        sessions = Array(sessions.suffix(100))
        nextDay = day.next
        persist()
    }

    func setNextDay(_ day: TrainingDay) {
        nextDay = day
        persist()
    }

    func seedNextWeights(_ imported: [String: Double]) {
        guard !imported.isEmpty else { return }
        nextWeights.merge(imported) { _, importedValue in importedValue }
        persist()
    }

    private func load() {
        if let raw = UserDefaults.standard.string(forKey: nextDayKey),
           let stored = TrainingDay(rawValue: raw) {
            nextDay = stored
        }

        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([LoggedStrengthSession].self, from: data) {
            sessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: detailedSessionsKey),
           let decoded = try? JSONDecoder().decode([DetailedStrengthSession].self, from: data) {
            detailedSessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: nextWeightsKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            nextWeights = decoded
        }
        if let data = UserDefaults.standard.data(forKey: activeWorkoutKey),
           let decoded = try? JSONDecoder().decode(ActiveStrengthWorkout.self, from: data) {
            activeWorkout = decoded
        }
    }

    private func persist() {
        UserDefaults.standard.set(nextDay.rawValue, forKey: nextDayKey)

        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
        if let data = try? JSONEncoder().encode(detailedSessions) {
            UserDefaults.standard.set(data, forKey: detailedSessionsKey)
        }
        if let data = try? JSONEncoder().encode(nextWeights) {
            UserDefaults.standard.set(data, forKey: nextWeightsKey)
        }
        if let activeWorkout, let data = try? JSONEncoder().encode(activeWorkout) {
            UserDefaults.standard.set(data, forKey: activeWorkoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
        }
    }
}
