# Board Box — Closed Testing Guide

Instructions for both the developer (Play Console setup) and testers (how to join and what to test).

---

## Part 1 — Developer: Setting Up the Closed Testing Track

### 1. Upload the AAB
1. Go to **Play Console → Board Box → Testing → Closed testing**
2. Click **Create new release**
3. Upload `app-release.aab` (from CI artifacts or `flutter build appbundle --release`)
4. Fill in **Release notes** (e.g. "Initial closed test build — 5 games, AI, local multiplayer")
5. Click **Save → Review release → Start rollout**

### 2. Add testers
1. Go to **Closed testing → Testers** tab
2. Either:
   - **Email list** — paste individual Gmail addresses (one per line)
   - **Google Group** — create a group at groups.google.com and paste the group email
3. Click **Save changes**
4. Copy the **opt-in URL** shown on the same page — share this with testers

### 3. Check release status
- The build usually takes **a few hours** to become available after rollout
- Status should change from "In review" → "Available on Google Play"

---

## Part 2 — Tester: How to Join

1. Open the **opt-in URL** shared by the developer on your Android device
2. Tap **Become a tester**
3. Tap the **download link** on that page — it opens the Play Store
4. Install **Board Box** normally from the Play Store
5. To leave the test: return to the opt-in URL and tap **Leave the program**

**Requirements:**
- Android device (phone or tablet)
- Google account that was added to the tester list
- Play Store app installed and signed in with that account

---

## Part 3 — What to Test

Work through each area below. Note anything unexpected and report it (see Part 4).

### Games — Basic flow
For each of the 5 games, do the following in **2-player mode**:

| Game | Key things to verify |
|------|---------------------|
| **Gomoku** | Stones place correctly · 5-in-a-row triggers win screen · Undo removes last stone |
| **Othello** | Discs flip correctly after placement · Pass happens when no valid moves · Game ends when neither player can move |
| **Checkers** | Red moves first · Mandatory capture enforced · Multi-jump chain completes · Piece promotes to king at back row · King moves/captures both directions |
| **Dots & Boxes** | Completing a box claims it and grants another turn · Game ends when all boxes are claimed · Score totals correctly |
| **Tic Tac Toe** | Test all 3 board sizes (3×3, 4×4, 5×5) · Win detection correct for each size |

### AI mode
Test each game vs AI at all three difficulty levels:

- [ ] Easy — AI makes random moves, manageable for new players
- [ ] Medium — AI plays with basic strategy
- [ ] Hard — AI is noticeably tougher
- [ ] AI move fires after player move without freezing or crashing

### Save & resume
- [ ] Start a game, go to the home screen (back button), re-open the same game → board state is restored
- [ ] Start a game, force-close the app, reopen → board state is restored
- [ ] Tap restart → board resets cleanly

### Settings
- [ ] **Dark mode** — toggle works, persists after closing and reopening the app
- [ ] **Move hints** — turning on highlights valid moves; turning off removes them
- [ ] **Haptic feedback** — toggle on/off; feel the difference when placing pieces
- [ ] **Fast AI moves** — AI responds faster when enabled

### Stats
- [ ] Win/loss/draw counts increment correctly after each game ends
- [ ] Stats persist after closing and reopening the app
- [ ] **Clear statistics** resets all counts to zero

### Privacy policy
- [ ] Go to **Settings → Privacy Policy** — page loads correctly inside the app
- [ ] The page is also accessible in a browser at:
  `https://learn-by-exploration.github.io/BoardBox/privacy-policy.html`

### Edge cases
- [ ] Tap rapidly during a game (no crash or double-move)
- [ ] Rotate the device mid-game (board redraws correctly)
- [ ] Navigate away mid-AI-move, then return (no stuck state)
- [ ] Start a game, switch to another game type from the home screen, return (no state bleed)

---

## Part 4 — How to Report Issues

Please report bugs with the following details:

1. **Device** — model and Android version (e.g. Pixel 7, Android 14)
2. **Game and mode** — e.g. "Checkers vs AI Hard"
3. **Steps to reproduce** — exactly what you tapped and in what order
4. **What happened** — describe the bug
5. **What you expected** — what should have happened
6. **Screenshot or screen recording** if possible

Send reports to the developer via the agreed channel (email / WhatsApp / GitHub issue).

---

## Part 5 — Known Limitations in This Build

- No online multiplayer — local 2-player only (by design)
- No sound effects
- Stats are per-device and not backed up to the cloud
- Screenshots taken for this test build have the device status bar visible — cosmetic only, does not affect gameplay

---

## Part 6 — Promoting to Production

Before moving from closed testing to production, confirm:

- [ ] No CRITICAL or HIGH bugs reported by testers
- [ ] All 5 games complete a full game without crashing
- [ ] AI works at all difficulty levels for all games
- [ ] Save/resume works reliably
- [ ] Privacy policy URL is live and accessible
- [ ] Play Console — all required sections complete:
  - [ ] Store listing (text + all images uploaded)
  - [ ] Privacy policy URL set
  - [ ] Content rating questionnaire submitted
  - [ ] Target audience set (All ages / Families)
  - [ ] Data safety form submitted
  - [ ] App category set (Games → Board)
  - [ ] Contact details filled in
