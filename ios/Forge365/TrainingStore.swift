import Foundation

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var sessions: [LoggedStrengthSession] = []
    @Published private(set) var nextDay: TrainingDay = .upperA

    private let sessionsKey = "forge365.strengthSessions"
    private let nextDayKey = "forge365.nextTrainingDay"

    init() {
        load()
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

    private func load() {
        if let raw = UserDefaults.standard.string(forKey: nextDayKey),
           let stored = TrainingDay(rawValue: raw) {
            nextDay = stored
        }

        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([LoggedStrengthSession].self, from: data) else {
            return
        }
        sessions = decoded
    }

    private func persist() {
        UserDefaults.standard.set(nextDay.rawValue, forKey: nextDayKey)
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}
