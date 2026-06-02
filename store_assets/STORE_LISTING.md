# Board Box — Google Play Store Listing

All text and asset details needed to fill in the Play Console store listing.

---

## Listing Text

### App name (9 / 30 chars)
```
Board Box
```

### Short description (74 / 80 chars)
```
5 classic board games. Local multiplayer & AI. No ads. No data collected.
```

### Full description (paste as-is)
```
Board Box brings five timeless strategy games together in one clean, ad-free app — perfect for passing time solo or battling a friend on the same device.

━━ 5 GAMES IN ONE ━━

♟ Gomoku — Get five in a row on a 15×15 grid. Easy to learn, deep to master.
🔵 Othello — Flip your opponent's discs and dominate the 8×8 board.
🔴 Checkers — Classic English draughts with mandatory captures, multi-jumps, and king promotion.
🔲 Dots & Boxes — Draw lines, complete boxes, score the most squares.
✖ Tic Tac Toe — Play on a 3×3, 4×4, or 5×5 board.

━━ FEATURES ━━

• Local 2-player — Play together on one device, no accounts needed.
• Single-player AI — Three difficulty levels: Easy, Medium, and Hard.
• Move hints — Highlight valid moves to help new players.
• Undo — Take back your last move in Gomoku and Tic Tac Toe.
• Game stats — Track your wins, losses, and draws for every game.
• Resume later — Leave a game and pick up exactly where you left off.
• Dark mode — Easy on the eyes in any lighting.
• Haptic feedback — Optional tactile response on every move.

━━ PRIVACY ━━

No ads. No tracking. No internet required. All data stays on your device. Safe for all ages and fully compliant with COPPA and GDPR.

Privacy policy: https://learn-by-exploration.github.io/BoardBox/privacy-policy.html
```

---

## Links

| Field | Value |
|-------|-------|
| Privacy policy URL | `https://learn-by-exploration.github.io/BoardBox/privacy-policy.html` |
| Data safety reference | `https://learn-by-exploration.github.io/BoardBox/data-safety.html` |
| GitHub repo | `https://github.com/learn-by-exploration/BoardBox` |

---

## Image Upload Checklist

Upload each file to the indicated slot in **Play Console → Store listing → Default (en-US)**.

### App icon
| File | Slot | Spec |
|------|------|------|
| `icon_512.png` | App icon | 512×512 PNG, ≤1 MB |

### Feature graphic
| File | Slot | Spec |
|------|------|------|
| `feature_graphic_1024x500.png` | Feature graphic | 1024×500 PNG/JPEG, ≤15 MB |

### Phone screenshots *(upload in order, 2–8 allowed)*
| # | File | Content |
|---|------|---------|
| 1 | `screenshot_phone_1_home.jpg` | Home screen — all 5 games (real device) |
| 2 | `screenshot_phone_2_dots_mode_select.jpg` | Dots & Boxes — mode / rules screen (real device) |
| 3 | `screenshot_phone_3_dots_game.jpg` | Dots & Boxes — game in progress (real device) |
| 4 | `screenshot_phone_4_checkers.png` | Checkers — mid-game (generated mockup) |
| 5 | `screenshot_phone_5_gomoku.png` | Gomoku — mid-game (generated mockup) |

### 7-inch tablet screenshots *(up to 8)*
| # | File | Content |
|---|------|---------|
| 1 | `tablet_7in_screenshot_1_home.png` | Home screen |
| 2 | `tablet_7in_screenshot_2_gomoku.png` | Gomoku mid-game |

### 10-inch tablet screenshots *(up to 8)*
| # | File | Content |
|---|------|---------|
| 1 | `tablet_10in_screenshot_1_home.png` | Home screen |
| 2 | `tablet_10in_screenshot_2_gomoku.png` | Gomoku mid-game |
| 3 | `tablet_10in_screenshot_3_checkers.png` | Checkers mid-game |

### Skip / leave blank
- Video — no YouTube video
- Chromebook screenshots — not required
- Google Play Games on PC — not applicable
- Android XR — not applicable

---

## Content Rating & Policy Answers

| Section | Answer |
|---------|--------|
| App access | All features accessible, no login required |
| Ads | No ads |
| Content rating | Everyone (no violence, no mature content) |
| Target audience | All ages including children — Families policy compliant |
| Data safety — collects data? | No |
| Data safety — shares data? | No |
| Data safety — encrypted in transit? | N/A (no data transmitted) |
| Data safety — user can request deletion? | Yes (uninstall removes all data) |
| Government apps | No |
| Financial features | No |
| Health | No |

---

## Regenerating Assets

All generated images were produced by a Python/Pillow script. To regenerate:

```bash
# Resize the source icon (2048×2048 app_icon.png → 512×512)
python3 -c "
from PIL import Image
img = Image.open('app_icon.png').convert('RGBA')
img.resize((512, 512), Image.LANCZOS).save('store_assets/icon_512.png')
"
```

For the feature graphic and screenshot mockups, run the generation scripts
that were used in the original session. The source app icon is at:
`board_box/app_icon.png` (2048×2048 RGBA PNG).

### Screenshot quality notes
- Phone screenshots 1–3 are **real device screenshots** — retake these when possible:
  - Use airplane mode to clear the status bar
  - Charge battery to 100%
  - Screenshot from the very top of the screen (avoid cropping)
  - Target resolution ≥1080px wide for promotional eligibility
- Screenshots 4–5 (checkers, gomoku) are **generated mockups** — replace with
  real device screenshots when retaking.
