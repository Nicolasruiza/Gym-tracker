import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "house.fill") }

            NavigationStack { TrainView() }
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }

            NavigationStack { EatView() }
                .tabItem { Label("Eat", systemImage: "fork.knife") }

            NavigationStack { HealthView() }
                .tabItem { Label("Health", systemImage: "heart.text.square.fill") }

            NavigationStack { CoachView() }
                .tabItem { Label("Coach", systemImage: "sparkles") }
        }
        .tint(ForgeTheme.green)
        .preferredColorScheme(.dark)
    }
}

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                metricStrip

                ForgeCard(title: "TRAIN", icon: "dumbbell.fill", accent: ForgeTheme.green) {
                    Text(model.plan.trainingTitle)
                        .font(.title2.bold())
                    Text(model.plan.trainingDetail)
                        .foregroundStyle(.secondary)

                    if model.training.activeWorkout == nil {
                        Button {
                            model.startTodayWorkout()
                        } label: {
                            Label("Start workout", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ForgeTheme.green)
                    } else {
                        Label("Workout in progress · continue in Train", systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ForgeTheme.green)
                    }
                }

                ForgeCard(title: "CARDIO / MOVE", icon: "figure.walk", accent: ForgeTheme.blue) {
                    Text(model.plan.cardioTitle)
                        .font(.title3.bold())
                    Text(model.plan.cardioDetail)
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "RECOVER", icon: "bed.double.fill", accent: ForgeTheme.purple) {
                    Text(model.plan.sleepTitle)
                        .font(.title3.bold())
                    Text(model.plan.sleepDetail)
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "EAT", icon: "fork.knife", accent: ForgeTheme.gold) {
                    Text(model.plan.nutritionTitle)
                        .font(.title3.bold())
                    Text(model.plan.nutritionDetail)
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "COACH", icon: "sparkles", accent: ForgeTheme.gold) {
                    Text(model.plan.coachMessage)
                        .font(.headline)
                    Text("Forge combines Apple Health with your detailed Lift Log history instead of asking you to remember what you did.")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await model.refresh() }
                } label: {
                    HStack {
                        if model.isLoading { ProgressView() }
                        Label("Refresh Health data", systemImage: "arrow.clockwise")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(ForgeTheme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("FORGE 365")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .tracking(2)
            Text("DAY \(model.dayNumber) OF 365 · RECOMPOSITION")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                statusPill("NO HIIT", icon: "bolt.slash.fill", color: ForgeTheme.green)
                statusPill("CARDIOLOGY PENDING", icon: "heart.fill", color: ForgeTheme.gold)
            }
            .padding(.top, 4)
        }
    }

    private var metricStrip: some View {
        let sleepValue = model.snapshot.sleep.lastNightHours > 0
            ? String(format: "%.1fh", model.snapshot.sleep.lastNightHours)
            : "—"

        return HStack(spacing: 8) {
            miniMetric("SLEEP", sleepValue)
            miniMetric("STEPS", model.snapshot.stepsToday > 0 ? model.snapshot.stepsToday.formatted() : "—")
            miniMetric("CARDIO 7D", "\(model.snapshot.cardioMinutesLast7Days)m")
        }
    }

    private func miniMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ForgeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusPill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.monospaced().weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct TrainView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showLiftLogImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("TRAIN")
                    .font(.largeTitle.weight(.black))

                if model.training.activeWorkout != nil {
                    LiveWorkoutView(
                        training: model.training,
                        onFinish: { model.finishActiveStrengthWorkout() },
                        onCancel: { model.cancelActiveStrengthWorkout() }
                    )
                } else {
                    ForgeCard(title: "NEXT BEST SESSION", icon: "dumbbell.fill", accent: ForgeTheme.green) {
                        Text(model.recommendedTrainingDay.rawValue)
                            .font(.title.bold())
                        Text(model.plan.trainingDetail)
                            .foregroundStyle(.secondary)

                        Button {
                            model.startTodayWorkout()
                        } label: {
                            Label("Start \(model.recommendedTrainingDay.rawValue)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ForgeTheme.green)

                        Menu {
                            ForEach(TrainingDay.allCases) { day in
                                Button(day.rawValue) { model.chooseNextTrainingDay(day) }
                            }
                        } label: {
                            Label("Override today's workout", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }

                ForgeCard(title: "LIFT LOG HISTORY", icon: "square.and.arrow.down.fill", accent: ForgeTheme.gold) {
                    if let analysis = model.liftLogAnalysis {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(analysis.profileName ?? "Lift Log")
                                    .font(.headline)
                                Text("\(analysis.sessions.count) sessions imported · progression weights synced")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ForgeTheme.green)
                        }
                    } else {
                        Text("Import the JSON export from Lift Log so Forge can inherit your current weights and understand exact exercises, sets and weekly muscle volume.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showLiftLogImporter = true
                    } label: {
                        Label(model.liftLogAnalysis == nil ? "Import Lift Log JSON" : "Re-import latest JSON", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ForgeTheme.gold)

                    if let error = model.liftLogImportError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let analysis = model.liftLogAnalysis {
                    ForgeCard(title: "WEEKLY MUSCLE VOLUME", icon: "chart.bar.fill", accent: ForgeTheme.green) {
                        ForEach(analysis.weeklyVolume) { volume in
                            MuscleVolumeRow(volume: volume)
                        }

                        if let deficit = analysis.topDeficit {
                            Text("Biggest current gap: \(deficit.muscle.label). Forge uses this as context for today's session instead of blindly following a calendar.")
                                .font(.footnote)
                                .foregroundStyle(ForgeTheme.gold)
                                .padding(.top, 4)
                        }
                    }
                }

                ForgeCard(title: "APPLE HEALTH · LAST 14 DAYS", icon: "applewatch", accent: ForgeTheme.blue) {
                    let strength = model.snapshot.workouts.filter(\.isStrength)
                    if strength.isEmpty {
                        Text("No strength workouts found in Health yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(strength.prefix(8)) { workout in
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }
            .padding()
        }
        .background(ForgeTheme.background)
        .navigationTitle("Forge 365")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showLiftLogImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importLiftLog(from: url) }
            case .failure:
                break
            }
        }
    }
}

struct LiveWorkoutView: View {
    @ObservedObject var training: TrainingStore
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if let active = training.activeWorkout {
            ForgeCard(title: "LIVE WORKOUT", icon: "timer", accent: ForgeTheme.green) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(active.day.rawValue)
                            .font(.title.bold())
                        Text("Started \(active.started.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(training.activeDefinitions.count) exercises")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(training.activeDefinitions) { exercise in
                ExerciseLogCard(training: training, exercise: exercise)
            }

            Button(action: onFinish) {
                Label("Finish workout", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ForgeTheme.green)
            .disabled(!training.canFinishActiveWorkout)

            if !training.canFinishActiveWorkout {
                Text("Log all 3 sets for every exercise before finishing. Progression is calculated when the session closes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive, action: onCancel) {
                Label("Cancel workout", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

struct ExerciseLogCard: View {
    @ObservedObject var training: TrainingStore
    let exercise: ForgeExercise

    private var weightBinding: Binding<Double> {
        Binding(
            get: { training.weight(for: exercise.id) },
            set: { training.setWeight($0, for: exercise.id) }
        )
    }

    private func repBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { training.rep(for: exercise.id, setIndex: index) },
            set: { training.setRep($0, for: exercise.id, setIndex: index) }
        )
    }

    private var hitAllTargets: Bool {
        (0..<3).allSatisfy { training.rep(for: exercise.id, setIndex: $0) >= exercise.targetReps }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.headline)
                    Text("3 × \(exercise.targetReps)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if hitAllTargets {
                    Label("PROGRESS", systemImage: "arrow.up.circle.fill")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(ForgeTheme.green)
                }
            }

            if exercise.startingWeight > 0 || exercise.increment > 0 {
                HStack {
                    Text("WEIGHT")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", value: weightBinding, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    Text("lb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("BODYWEIGHT / TIME")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text("SET \(index + 1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        TextField("0", value: repBinding(index), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(ForgeTheme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(hitAllTargets ? ForgeTheme.green.opacity(0.7) : Color.white.opacity(0.05), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MuscleVolumeRow: View {
    let volume: MuscleVolume

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(volume.muscle.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(volume.effectiveSets.formatted(.number.precision(.fractionLength(1)))) / \(volume.targetSets.formatted(.number.precision(.fractionLength(0)))) sets")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(volume.deficit > 0.5 ? .secondary : ForgeTheme.green)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(volume.deficit > 0.5 ? ForgeTheme.gold : ForgeTheme.green)
                        .frame(width: geometry.size.width * min(1, volume.completion))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 3)
    }
}

struct EatView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("EAT")
                    .font(.largeTitle.weight(.black))

                if let targets = model.nutritionTargets {
                    ForgeCard(title: "TODAY'S TARGET", icon: "target", accent: ForgeTheme.gold) {
                        Text("\(targets.calories) kcal")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        HStack(spacing: 8) {
                            MacroTile(label: "PROTEIN", value: "\(targets.proteinG)g")
                            MacroTile(label: "CARBS", value: "\(targets.carbsG)g")
                            MacroTile(label: "FAT", value: "\(targets.fatG)g")
                        }
                        Text(targets.calibrationSource)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("This is a starting calibration, not a permanent calorie prescription. Forge should change it only after enough body-trend and performance data accumulate.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForgeCard(title: "HEART-AWARE GUARDRAILS", icon: "heart.fill", accent: ForgeTheme.gold) {
                        nutritionLine("Saturated fat", "≤ \(targets.saturatedFatMaxG) g/day")
                        nutritionLine("Fiber", "≥ \(targets.fiberMinG) g/day")
                        Text("Favor vegetables, fruit, legumes, nuts, whole grains, lean protein, olive oil and fish. Keep processed meats, trans fat, sugary drinks and heavily refined foods occasional rather than foundational.")
                            .foregroundStyle(.secondary)
                    }

                    ForgeCard(title: "WHAT TO EAT", icon: "fork.knife", accent: ForgeTheme.green) {
                        MealIdea(title: "Breakfast", text: "Protein + fiber-rich carb + fruit. Example: Greek yogurt or cottage cheese, oats/berries, whey if needed.")
                        MealIdea(title: "Lunch", text: "Lean protein + vegetables + potato, rice, whole grain or legumes + an unsaturated-fat source such as olive oil.")
                        MealIdea(title: "Around training", text: "Use some of today's carbs where they help: fruit, oats, potato, rice or whole grains. You do not need a special sugar drink for a normal lifting session.")
                        MealIdea(title: "Dinner", text: "Fish, chicken, legumes or lean meat + plenty of vegetables + a quality carb if it fits the day's target.")
                    }

                    ForgeCard(title: "CARBS", icon: "bolt.fill", accent: ForgeTheme.blue) {
                        Text("Carbs are the remainder after protein and adequate fat — not a moral category. On lifting days, Forge can bias more of them toward the meals before and after training. On rest days, total intake matters more than forcing a carb quota.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForgeCard(title: "NEEDS ONE INPUT", icon: "scalemass.fill", accent: ForgeTheme.gold) {
                        Text("Forge couldn't find a usable body-weight entry in Apple Health. Add or sync your weight there, then refresh Health data. That unlocks the first nutrition calibration without making you maintain the same number in two places.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(ForgeTheme.background)
        .navigationTitle("Forge 365")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nutritionLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
    }
}

struct MacroTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MealIdea: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.bold))
            Text(text).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

struct HealthView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("HEALTH")
                    .font(.largeTitle.weight(.black))

                ForgeCard(title: "SLEEP", icon: "moon.zzz.fill", accent: ForgeTheme.purple) {
                    healthMetric("Last night", hours(model.snapshot.sleep.lastNightHours))
                    healthMetric("7-day average", hours(model.snapshot.sleep.sevenDayAverageHours))
                    healthMetric("Deep", hours(model.snapshot.sleep.deepHours))
                    healthMetric("REM", hours(model.snapshot.sleep.remHours))
                }

                ForgeCard(title: "BODY + ENERGY", icon: "scalemass.fill", accent: ForgeTheme.gold) {
                    healthMetric("Body weight", model.healthKit.bodyWeightKg.map { String(format: "%.1f kg", $0) } ?? "—")
                    healthMetric("7-day energy", model.healthKit.averageDailyEnergyBurned7d.map { "\(Int($0.rounded())) kcal/day" } ?? "—")
                    Text("Energy expenditure from wearables is only a starting estimate. Forge should calibrate it against actual weight and waist trends before making meaningful calorie changes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "RECOVERY SIGNALS", icon: "waveform.path.ecg", accent: ForgeTheme.green) {
                    healthMetric("Resting HR", model.snapshot.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—")
                    healthMetric("HRV (SDNN)", model.snapshot.hrvSDNN.map { "\(Int($0.rounded())) ms" } ?? "—")
                    healthMetric("Steps today", model.snapshot.stepsToday > 0 ? model.snapshot.stepsToday.formatted() : "—")
                    Text("Forge treats these as context and trends, not as a medical diagnosis or a one-number readiness score.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "RECENT WORKOUTS", icon: "applewatch", accent: ForgeTheme.blue) {
                    if model.snapshot.workouts.isEmpty {
                        Text("No HealthKit workouts available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.snapshot.workouts.prefix(12)) { workout in
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }
            .padding()
        }
        .background(ForgeTheme.background)
        .navigationTitle("Forge 365")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hours(_ value: Double) -> String {
        value > 0 ? String(format: "%.1f h", value) : "—"
    }

    private func healthMetric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
        .padding(.vertical, 3)
    }
}

struct CoachView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("COACH")
                    .font(.largeTitle.weight(.black))

                ForgeCard(title: "TODAY'S DECISION", icon: "sparkles", accent: ForgeTheme.gold) {
                    Text(model.plan.coachMessage)
                        .font(.title3.bold())
                }

                ForgeCard(title: "WHY", icon: "brain.head.profile", accent: ForgeTheme.green) {
                    ForEach(model.plan.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                ForgeCard(title: "SAFETY RAIL", icon: "heart.fill", accent: ForgeTheme.gold) {
                    Text("CAC context is stored as a constraint, not as permission for Forge to practice cardiology. Until clinician guidance is entered, Forge avoids maximal-intensity prescriptions and does not fabricate heart-rate limits.")
                        .foregroundStyle(.secondary)
                }

                ForgeCard(title: "COMING NEXT", icon: "hammer.fill", accent: ForgeTheme.blue) {
                    Text("1. Food logging + saved meals\n2. Weight + waist trend engine\n3. Weekly coach review\n4. WorkoutKit / Apple Watch delivery\n5. Exercise substitutions and injury holds")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(ForgeTheme.background)
        .navigationTitle("Forge 365")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.isStrength ? "dumbbell.fill" : workout.isCardio ? "figure.walk" : "figure.run")
                .frame(width: 28, height: 28)
                .foregroundStyle(workout.isStrength ? ForgeTheme.green : ForgeTheme.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName).font(.subheadline.bold())
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(workout.durationMinutes)m")
                .font(.subheadline.monospacedDigit().bold())
        }
        .padding(.vertical, 5)
    }
}

struct ForgeCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    let content: Content

    init(title: String, icon: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: icon)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(accent)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ForgeTheme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

enum ForgeTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.082)
    static let card = Color(red: 0.10, green: 0.13, blue: 0.145)
    static let green = Color(red: 0.27, green: 0.72, blue: 0.49)
    static let blue = Color(red: 0.32, green: 0.64, blue: 0.93)
    static let purple = Color(red: 0.63, green: 0.52, blue: 0.93)
    static let gold = Color(red: 0.86, green: 0.67, blue: 0.30)
}
