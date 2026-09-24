# Forge 365 iOS — vertical slice

This folder is the native iOS evolution of Lift Log. The existing web app remains untouched.

## What works in this first slice

- SwiftUI shell with Today / Train / Health / Coach
- Reads Apple Health workouts regardless of whether they were started in Forge, Apple Workout, or another app that writes to HealthKit
- Reads sleep stages, steps, resting heart rate, and HRV from HealthKit
- Keeps the Lift Log rotation (Upper A / Legs / Upper B) as a native local state
- Daily coach decision uses recent strength sessions, aerobic minutes, and sleep
- HIIT is excluded from recommendations by preference
- Cardiovascular safety rail: while cardiology guidance is pending, Forge does not invent heart-rate limits or prescribe maximal-intensity work
- Background HealthKit observer scaffolding for workout/sleep changes

## Not done yet

1. Import detailed Lift Log set/rep/weight history from the web app export
2. Per-muscle weekly volume and adaptive workout composition
3. Nutrition onboarding, calorie/protein targets, meal logging, and carb allocation
4. Weight/waist/photos and recomposition trend engine
5. Weekly review and automatic phase adjustments
6. WorkoutKit delivery to Apple Watch
7. Cloud sync / backend

## Run

1. Open `Forge365.xcodeproj` in Xcode.
2. Select the Forge365 target and your Apple Developer team.
3. In **Signing & Capabilities**, confirm **HealthKit** is enabled and Background Delivery is checked.
4. Change the bundle identifier if your signing account requires it.
5. Run on a physical iPhone. HealthKit background delivery is not supported by the Simulator.
6. Accept the Health permissions Forge requests.

The project currently targets iOS 18+ and uses only public SwiftUI + HealthKit APIs.
