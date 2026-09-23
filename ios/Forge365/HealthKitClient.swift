import Foundation
import Combine
import HealthKit

@MainActor
final class HealthKitClient: ObservableObject {
    @Published private(set) var authorizationRequested = false
    @Published private(set) var lastError: String?
    @Published private(set) var bodyWeightKg: Double?
    @Published private(set) var averageDailyEnergyBurned7d: Double?

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    private var workoutType: HKWorkoutType { HKObjectType.workoutType() }
    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }
    private var stepType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .stepCount) }
    private var restingHRType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .restingHeartRate) }
    private var hrvType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) }
    private var bodyMassType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .bodyMass) }
    private var activeEnergyType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) }
    private var basalEnergyType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "Health data is not available on this device."
            return
        }

        var readTypes = Set<HKObjectType>()
        readTypes.insert(workoutType)
        [sleepType, stepType, restingHRType, hrvType, bodyMassType, activeEnergyType, basalEnergyType]
            .compactMap { $0 }
            .forEach { readTypes.insert($0) }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationRequested = true
            lastError = nil
            startObservers()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func readSnapshot() async -> HealthSnapshot {
        async let workouts = loadWorkouts(days: 14)
        async let sleep = loadSleepSummary(days: 8)
        async let steps = loadStepsToday()
        async let restingHR = loadLatestQuantity(type: restingHRType, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
        async let hrv = loadLatestQuantity(type: hrvType, unit: HKUnit.secondUnit(with: .milli))
        async let weight = loadLatestQuantity(type: bodyMassType, unit: HKUnit.gramUnit(with: .kilo))
        async let activeEnergy = loadCumulativeQuantity(type: activeEnergyType, unit: HKUnit.kilocalorie(), days: 7)
        async let basalEnergy = loadCumulativeQuantity(type: basalEnergyType, unit: HKUnit.kilocalorie(), days: 7)

        let resolvedWorkouts = await workouts
        let resolvedSleep = await sleep
        let resolvedSteps = await steps
        let resolvedRestingHR = await restingHR
        let resolvedHRV = await hrv
        let resolvedWeight = await weight
        let resolvedActiveEnergy = await activeEnergy
        let resolvedBasalEnergy = await basalEnergy

        bodyWeightKg = resolvedWeight
        if resolvedActiveEnergy > 0 && resolvedBasalEnergy > 0 {
            averageDailyEnergyBurned7d = (resolvedActiveEnergy + resolvedBasalEnergy) / 7.0
        } else {
            averageDailyEnergyBurned7d = nil
        }

        return HealthSnapshot(
            workouts: resolvedWorkouts,
            sleep: resolvedSleep,
            stepsToday: resolvedSteps,
            restingHeartRate: resolvedRestingHR,
            hrvSDNN: resolvedHRV
        )
    }

    private func loadWorkouts(days: Int) async -> [WorkoutRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout] ?? []).map { workout in
                    let type = workout.workoutActivityType
                    return WorkoutRecord(
                        id: workout.uuid,
                        activityName: Self.activityName(type),
                        startDate: workout.startDate,
                        durationMinutes: max(1, Int(workout.duration / 60.0)),
                        sourceName: workout.sourceRevision.source.name,
                        isStrength: Self.isStrength(type),
                        isCardio: Self.isCardio(type)
                    )
                }
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private func loadStepsToday() async -> Int {
        guard let type = stepType else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(total.rounded()))
            }
            store.execute(query)
        }
    }

    private func loadLatestQuantity(type: HKQuantityType?, unit: HKUnit) async -> Double? {
        guard let type else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func loadCumulativeQuantity(type: HKQuantityType?, unit: HKUnit, days: Int) async -> Double {
        guard let type else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }

    private func loadSleepSummary(days: Int) async -> SleepSummary {
        guard let type = sleepType else { return .empty }
        let start = Calendar.current.date(byAdding: .day, value: -(days + 1), to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }

        let asleepSamples = samples.filter { Self.isAsleepValue($0.value) }
        guard !asleepSamples.isEmpty else { return .empty }

        let grouped = Dictionary(grouping: asleepSamples) { $0.sourceRevision.source.bundleIdentifier }
        let selected: [HKCategorySample]
        if let bestSourceSamples = grouped.values.max(by: { lhs, rhs in
            Self.mergedDuration(lhs) < Self.mergedDuration(rhs)
        }) {
            selected = Array(bestSourceSamples)
        } else {
            selected = asleepSamples
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var nightlyHours: [Double] = []

        for offset in 0..<days {
            guard let anchor = calendar.date(byAdding: .day, value: -offset, to: today),
                  let windowStart = calendar.date(byAdding: .hour, value: -12, to: anchor),
                  let windowEnd = calendar.date(byAdding: .hour, value: 12, to: anchor) else { continue }

            let nightly = selected.filter { $0.endDate > windowStart && $0.startDate < windowEnd }
            let hours = Self.mergedDuration(nightly, clippedTo: windowStart...windowEnd) / 3600.0
            if hours > 0.5 { nightlyHours.append(hours) }
        }

        let lastNight = nightlyHours.first ?? 0
        let average = nightlyHours.isEmpty ? 0 : nightlyHours.reduce(0, +) / Double(nightlyHours.count)

        guard let lastStart = calendar.date(byAdding: .hour, value: -12, to: today),
              let lastEnd = calendar.date(byAdding: .hour, value: 12, to: today) else {
            return SleepSummary(lastNightHours: lastNight, sevenDayAverageHours: average, deepHours: 0, remHours: 0)
        }

        let lastNightSamples = selected.filter { $0.endDate > lastStart && $0.startDate < lastEnd }
        let deep = lastNightSamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
        let rem = lastNightSamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }

        return SleepSummary(
            lastNightHours: lastNight,
            sevenDayAverageHours: average,
            deepHours: Self.mergedDuration(deep, clippedTo: lastStart...lastEnd) / 3600.0,
            remHours: Self.mergedDuration(rem, clippedTo: lastStart...lastEnd) / 3600.0
        )
    }

    private func startObservers() {
        guard observerQueries.isEmpty else { return }

        var observedTypes: [HKSampleType] = [workoutType]
        if let sleepType { observedTypes.append(sleepType) }
        if let bodyMassType { observedTypes.append(bodyMassType) }

        for type in observedTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                    completion()
                }
            }
            observerQueries.append(query)
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    private static func isAsleepValue(_ value: Int) -> Bool {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        return asleepValues.contains(value)
    }

    private static func mergedDuration(_ samples: [HKCategorySample], clippedTo range: ClosedRange<Date>? = nil) -> TimeInterval {
        var intervals = samples.map { sample -> (Date, Date) in
            let start = max(sample.startDate, range?.lowerBound ?? sample.startDate)
            let end = min(sample.endDate, range?.upperBound ?? sample.endDate)
            return (start, end)
        }.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }

        guard var current = intervals.first else { return 0 }
        intervals.removeFirst()
        var total: TimeInterval = 0

        for interval in intervals {
            if interval.0 <= current.1 {
                current.1 = max(current.1, interval.1)
            } else {
                total += current.1.timeIntervalSince(current.0)
                current = interval
            }
        }
        total += current.1.timeIntervalSince(current.0)
        return total
    }

    private static func isStrength(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return true
        default:
            return false
        }
    }

    private static func isCardio(_ type: HKWorkoutActivityType) -> Bool {
        switch type {
        case .walking, .running, .cycling, .elliptical, .rowing, .hiking, .stairClimbing, .mixedCardio, .swimming:
            return true
        default:
            return false
        }
    }

    private static func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walk"
        case .running: return "Run"
        case .cycling: return "Cycling"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .hiking: return "Hiking"
        case .stairClimbing: return "Stair Climbing"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .coreTraining: return "Core Training"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .highIntensityIntervalTraining: return "HIIT"
        case .mixedCardio: return "Mixed Cardio"
        default: return "Workout"
        }
    }
}
