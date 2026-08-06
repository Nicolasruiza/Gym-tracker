# Lift Log

A single-file workout tracker for a 3-day rotation (Upper A / Legs / Upper B).
No build step, no backend — the whole app is `index.html`.

## What it does

- Three training days with fixed exercise blocks (basics, compound, isolation, core)
- Logs 3 sets per exercise; weight moves up automatically only when all 3 sets hit target reps
- Rest-day gate: warns (or blocks) if you already trained today or trained yesterday
- Plate math for barbell lifts, dual-cable multipliers, bodyweight-strength badges
- Injury holds freeze progression on specific lifts
- History tab: weight progression per lift and a session log with total volume
- Export / import your data as JSON

## Data

Everything lives in the browser's local storage, tied to the exact URL you open it from.
Nothing is uploaded. Use **EXPORT** before switching URLs or clearing site data.

## Hosting

See [hosting-steps.md](hosting-steps.md) for GitHub Pages setup and adding it to your phone's home screen.
