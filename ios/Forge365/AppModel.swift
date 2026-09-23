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

    func start() async {
        await healthKit.requestAuthorization()
        await refresh()
    }

    func refresh() async {
        isLoading = true
        snapshot = await healthKit.readSnapshot()
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
            liftLog: liftLogAnalysis,
            nutrition: nutritionTargets
        )
    }

    private func ensureStartDate() {
        if UserDefaults.standard.object(forKey: startDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: startDateKey)
        }
    }
}
