# Putting Lift Log on GitHub Pages

Goal: a real URL you open in Safari, that remembers your history and sits on your home screen like an app.

## 1. Create the repo
- github.com → **New repository**
- Name: `liftlog` · **Public** · don't add a README
- Create

## 2. Upload the file
- **Add file → Upload files**
- Drag in `liftlog-v2.html`
- **Rename it to `index.html`** — this matters, Pages serves `index.html` by default
- Commit

## 3. Turn on Pages
- **Settings → Pages**
- Source: **Deploy from a branch**
- Branch: `main`, folder: `/ (root)` → Save
- Wait ~1 minute, then reload the page to see your URL:
  `https://<your-username>.github.io/liftlog/`

## 4. Put it on your phone
- Open that URL in **Safari** (not the Files app)
- Share → **Add to Home Screen**
- It now opens full-screen with no browser chrome

## Things worth knowing

**Why the downloaded file looked empty.** Opening an `.html` from the Files app usually shows a preview that doesn't run JavaScript, and this app builds its whole screen with JavaScript. Same file opened in Safari works fine. Hosting it removes the problem entirely.

**Your data stays on your phone.** It lives in that browser, tied to that exact URL — it is never uploaded to GitHub. The repo only holds the app.

**Public repo, private data.** Anyone with the link can see the app; nobody can see your sessions.

**Moving between URLs.** Data does not follow you from the Claude preview to your GitHub URL. Use **EXPORT** on the old one and **IMPORT** on the new one.

**Updating later.** When I send a new version: repo → `index.html` → pencil icon → paste the new contents → commit. Your history is untouched, it lives in the browser, not the file.

**Don't clear Safari website data** for that site, or the history goes with it. Export occasionally.
