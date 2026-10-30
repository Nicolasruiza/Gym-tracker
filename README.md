# Lift Log

A single-file workout tracker. Both profiles (Nicolas and Sofia/SA) run a 4-day rotation (Upper A / Legs A / Upper B / Legs B).
No build step, no backend — the whole app is `index.html`.

## What it does

- Each day has 4 main lifts (about 50 minutes at ~12 min per lift) plus a "Bonus · if time" block; the session counts as complete when the main lifts are logged
- Legs twice per rotation: squat + glutes (hip thrust, split squat, single-leg box squat, hip abduction) and hinge + single leg (single-leg RDL for balance, RDL, step-up, farmer carry)
- Logs 3 sets per exercise; weight moves up automatically only when all 3 sets hit target reps
- Rest-day gate: warns (or blocks) if you already trained today or trained yesterday
- Plate math for barbell lifts, dual-cable multipliers, bodyweight-strength badges
- Injury holds freeze progression on specific lifts
- History tab: weight progression per lift and a session log with total volume
- Recomp week view: the 4 lifting days plus Zone 2 (or office walking days on Tue/Thu, with the 4×4 on Sunday; per-profile toggle), a weekly 4×4 VO2 session with a built-in interval timer, and jump (impact) work before leg days for bone density; heart-rate targets from age; cardio and jumps are logged per profile and included in export
- Export / import your data as JSON

## Data

Everything lives in the browser's local storage, tied to the exact URL you open it from.
Nothing is uploaded. Use **EXPORT** before switching URLs or clearing site data.

## Hosting

See [hosting-steps.md](hosting-steps.md) for GitHub Pages setup and adding it to your phone's home screen.
