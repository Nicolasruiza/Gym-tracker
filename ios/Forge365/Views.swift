import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "house.fill") }

            NavigationStack { TrainView() }
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }

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

                    Button {
                        model.completeCurrentStrengthSession()
                    } label: {
                        Label("Mark strength session complete", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ForgeTheme.green)
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
                    Text("Forge is using your actual Health data instead of asking you to re-enter workouts, steps, or sleep.")
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("TRAIN")
                    .font(.largeTitle.weight(.black))

                ForgeCard(title: "NEXT BEST SESSION", icon: "dumbbell.fill", accent: ForgeTheme.green) {
                    Text(model.training.nextDay.rawValue)
                        .font(.title.bold())
                    Text(model.training.nextDay.summary)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(TrainingDay.allCases) { day in
                            Button(day.rawValue) { model.chooseNextTrainingDay(day) }
                        }
                    } label: {
                        Label("Change next workout", systemImage: "arrow.triangle.2.circlepath")
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

                ForgeCard(title: "LIFT LOG MIGRATION", icon: "arrow.down.doc.fill", accent: ForgeTheme.gold) {
                    Text("HealthKit knows that you lifted, but it doesn't know your bench sets, reps, RIR, or muscle volume. The next engineering slice imports the detailed Lift Log history so Forge can balance weekly muscle stimulus instead of only counting strength sessions.")
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
                    Text("1. Import detailed Lift Log sets and progression\n2. Nutrition targets + foods + carbs around training\n3. Weight + waist trend engine\n4. Weekly coach review\n5. WorkoutKit / Apple Watch delivery")
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
