import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: HealthSnapshot = .empty
    @Published private(set) var plan: DailyPlan
    @Published private(set) var isLoading = false

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

    func completeCurrentStrengthSession() {
        training.complete(training.nextDay)
        rebuildPlan()
    }

    func chooseNextTrainingDay(_ day: TrainingDay) {
        training.setNextDay(day)
        rebuildPlan()
    }

    private func rebuildPlan() {
        plan = CoachEngine.makePlan(snapshot: snapshot, nextTrainingDay: training.nextDay, profile: profile)
    }

    private func ensureStartDate() {
        if UserDefaults.standard.object(forKey: startDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: startDateKey)
        }
    }
}
