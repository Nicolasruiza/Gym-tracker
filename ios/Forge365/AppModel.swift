import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: HealthSnapshot = .empty
    @Published private(set) var plan: DailyPlan
    @Published private(set) var isLoading = false
    @Published private(set) var liftLogAnalysis: LiftLogAnalysis?
    @Published private(set) var liftLogImportError: String?

    let healthKit = HealthKitClient()
    let training = TrainingStore()
    let profile = CoachProfile.defaultProfile

    private let startDateKey = "forge365.startDate"

    init() {
        plan = CoachEngine.makePlan(snapshot: .empty, nextTrainingDay: .upperA, profile: .defaultProfile)
        ensureStartDate()
        rebuildPlan()
    }

    var dayNumber: Int {
        guard let start = UserDefaults.standard.object(forKey: startDateKey) as? Date else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return min(365, max(1, days + 1))
    }

    var recommendedTrainingDay: TrainingDay {
        training.activeWorkout?.day ?? training.nextDay
    }

    var nutritionTargets: NutritionTargets? {
        NutritionEngine.makeTargets(
            bodyWeightKg: healthKit.bodyWeightKg,
            averageDailyEnergyBurned: healthKit.averageDailyEnergyBurned7d
        )
    }

    var trainingAnalysis: LiftLogAnalysis? {
        combinedTrainingAnalysis()
    }

    func start() async {
        await healthKit.requestAuthorization()
        await refresh()
    }

    func refresh() async {
        isLoading = true
        snapshot = await healthKit.readSnapshot()
        applyConfirmedWalks()
        rebuildPlan()
        isLoading = false
    }

    func importLiftLog(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let analysis = try LiftLogImporter.parse(data: data)
            liftLogAnalysis = analysis
            liftLogImportError = nil
            training.seedNextWeights(LiftLogWeightImporter.nextWeights(from: data))
            if let recommended = analysis.recommendedNextDay, training.activeWorkout == nil {
                training.setNextDay(recommended)
            }
            rebuildPlan()
        } catch {
            liftLogImportError = error.localizedDescription
        }
    }

    func confirmWalkAsCardio(_ id: UUID) {
        var confirmed = Set(UserDefaults.standard.stringArray(forKey: "forge365.cardioWalks") ?? [])
        if confirmed.contains(id.uuidString) {
            confirmed.remove(id.uuidString)
        } else {
            confirmed.insert(id.uuidString)
        }
        UserDefaults.standard.set(Array(confirmed), forKey: "forge365.cardioWalks")
        applyConfirmedWalks()
        rebuildPlan()
    }

    private func applyConfirmedWalks() {
        let confirmed = Set(UserDefaults.standard.stringArray(forKey: "forge365.cardioWalks") ?? [])
        snapshot.workouts = snapshot.workouts.map { workout in
            var updated = workout
            if workout.needsCardioConfirmation {
                updated.isCardio = confirmed.contains(workout.id.uuidString)
            }
            return updated
        }
    }

    func startTodayWorkout() {
        training.startWorkout(day: training.nextDay)
        rebuildPlan()
    }

    func finishActiveStrengthWorkout() {
        training.finishActiveWorkout()
        rebuildPlan()
    }

    func cancelActiveStrengthWorkout() {
        training.cancelActiveWorkout()
        rebuildPlan()
    }

    func completeCurrentStrengthSession() {
        if training.activeWorkout == nil {
            startTodayWorkout()
        } else if training.canFinishActiveWorkout {
            finishActiveStrengthWorkout()
        }
    }

    func chooseNextTrainingDay(_ day: TrainingDay) {
        guard training.activeWorkout == nil else { return }
        training.setNextDay(day)
        rebuildPlan()
    }

    private func rebuildPlan() {
        plan = CoachEngine.makePlan(
            snapshot: snapshot,
            nextTrainingDay: training.nextDay,
            profile: profile,
            liftLog: combinedTrainingAnalysis(),
            nutrition: nutritionTargets,
            nativeSessions: training.sessions
        )
    }

    private func combinedTrainingAnalysis(now: Date = Date()) -> LiftLogAnalysis? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        let base = liftLogAnalysis
        let nativeStart = max(cutoff, base?.importedAt ?? cutoff)
        let newNativeSessions = training.detailedSessions.filter { $0.date >= nativeStart }

        guard base != nil || !newNativeSessions.isEmpty else { return nil }

        var effectiveSets = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 0.0) })
        var targets = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, defaultTarget(for: $0)) })

        if let base, base.importedAt >= cutoff {
            for volume in base.weeklyVolume {
                effectiveSets[volume.muscle] = volume.effectiveSets
                targets[volume.muscle] = volume.targetSets
            }
        }

        for session in newNativeSessions {
            for exercise in session.exercises {
                let setCount = Double(exercise.reps.filter { $0 > 0 }.count)
                guard setCount > 0 else { continue }
                let credit = muscleCredit(for: exercise.id)
                for muscle in credit.primary {
                    effectiveSets[muscle, default: 0] += setCount
                }
                for muscle in credit.secondary {
                    effectiveSets[muscle, default: 0] += setCount * 0.5
                }
            }
        }

        let weeklyVolume = MuscleGroup.allCases.map { muscle in
            MuscleVolume(
                muscle: muscle,
                effectiveSets: effectiveSets[muscle, default: 0],
                targetSets: targets[muscle, default: defaultTarget(for: muscle)]
            )
        }

        var summaries = base?.sessions ?? []
        summaries.append(contentsOf: newNativeSessions.map { session in
            LiftLogSessionSummary(
                id: session.id,
                date: session.date,
                day: session.day,
                exerciseCount: session.exercises.count,
                totalLoggedSets: session.exercises.reduce(0) { partial, exercise in
                    partial + exercise.reps.filter { $0 > 0 }.count
                }
            )
        })

        return LiftLogAnalysis(
            profileName: base?.profileName ?? "Forge 365",
            sessions: summaries.sorted(by: { $0.date > $1.date }),
            weeklyVolume: weeklyVolume,
            importedAt: base?.importedAt ?? now
        )
    }

    private func defaultTarget(for muscle: MuscleGroup) -> Double {
        switch muscle {
        case .chest, .back, .shoulders, .arms, .glutes: return 12
        case .hamstrings, .quads, .core: return 10
        case .calves: return 8
        }
    }

    private func muscleCredit(for exerciseID: String) -> (primary: [MuscleGroup], secondary: [MuscleGroup]) {
        switch exerciseID {
        case "leg_raise", "cbl_crunch", "plank", "pallof":
            return ([.core], [])
        case "bb_press", "db_incl":
            return ([.chest], [.arms, .shoulders])
        case "m_fly":
            return ([.chest], [])
        case "db_ohp":
            return ([.shoulders], [.arms])
        case "lat_raise":
            return ([.shoulders], [])
        case "face_pull":
            return ([.shoulders], [.back])
        case "lat_pull", "pullup":
            return ([.back], [.arms])
        case "db_row", "cbl_row":
            return ([.back], [.arms])
        case "cbl_tri", "skull", "db_curl", "bb_curl", "hammer":
            return ([.arms], [])
        case "gob_squat":
            return ([.quads, .glutes], [.core])
        case "leg_press":
            return ([.quads, .glutes], [])
        case "rdl":
            return ([.hamstrings, .glutes], [.back])
        case "ham_curl":
            return ([.hamstrings], [])
        case "leg_ext":
            return ([.quads], [])
        case "calf":
            return ([.calves], [])
        default:
            return ([], [])
        }
    }

    private func ensureStartDate() {
        if UserDefaults.standard.object(forKey: startDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: startDateKey)
        }
    }
}
