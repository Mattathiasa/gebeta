# Gebeta — Project Status

> Session log: full build of v1 (Phases 0–5), from empty folder to a
> tested, shippable app. Last updated: 2026-10-16.

## TL;DR

A polished digital **Gebeta** (traditional Ethiopian mancala) — Flutter
web + Android, EN/አማ, AI opponents, room-code online play, AdMob on
Android only, **100% free stack** (no billing account anywhere).

- `flutter analyze` → **clean**
- `flutter test` → **39 tests green**
- `flutter build web --release` → **✓**
- `flutter build apk --debug` → **✓**

---

## What shipped

### Phase 0 — Scaffold
- Flutter **web + Android** project `gebeta/` (Flutter 3.47.5, Dart 3.13)
- Riverpod + go_router, FlameUp-style feature-first layout (`core/`,
  `features/*`, `shared/`)
- l10n **EN / አማ** with bundled NotoSansEthiopic (offline, all weights)
- Wood/honey theme tokens (`lib/core/theme/`)
- Firebase bootstrap with karaoki's placeholder-detection pattern —
  the app **runs in stub mode with zero cloud setup**
- Registered as `gebeta` in `../run_flutter_app.sh`

### Phase 1 — Engine + AI (pure Dart)
- `lib/features/game/domain/game_engine.dart` — immutable states, the
  full "classic" 12-pit/4-seed ruleset:
  - sow with full-lap origin skip
  - capture chain (2-or-3 backward) + own-row fallback rule
  - starvation rules (can't empty the opponent unless forced; must
    give seeds to an empty opponent)
  - forced pass, 2-pass game over, 50-quiet-ply stalemate cap
  - win = more than 24 of 48 (24–24 draw)
- `lib/features/game/domain/ai_engine.dart` — minimax + alpha-beta,
  move ordering, 3 difficulties; **hard** = iterative deepening with a
  900 ms budget, runs in a background isolate
- Tests: capture chains, starvation edge cases, **200 randomized games
  with seed-conservation invariant**, hard-AI beats easy-AI in self-play
- Rules documented for review: `docs/RULESETS.md` (regional variants
  exist — user is final arbiter)

### Phase 2 — Playable app
- Animated board (`widgets/pit_circle.dart`, `widgets/gebeta_board.dart`):
  per-seed sow highlight, capture flash, legal-move glow, mirrored rows
  so the sow path reads as one loop
- `GameState`/`GameController` (Riverpod Notifier): human-vs-AI loop,
  randomized starter, match tally, difficulty switching mid-session
- Screens: home hub with W/L/D chips, tutorial (3 illustrated steps),
  AI game + result bottom sheet, quit flow
- Stats persisted on-device via `shared_preferences`
- Board widget takes state + tap callback as inputs → reused by both
  AI and online modes; board auto-flips if you're seated Player.b

### Phase 3 — Online PvP (free-tier compatible)
- Room codes (4 letters, no 0/O/1/I), create/join/copy-to-clipboard
- `RoomRepository` interface with two implementations:
  - **RTDB** (Firebase configured): code-existence node, room + state
    nodes, `onDisconnect` presence, transaction-enforced moves
  - **Stub** (in-memory): identical contract — powers dev/tests with
    no Firebase
- **Dual-compute move validation** (replaces server authority):
  Cloud Functions need a Blaze billing account, so instead every
  client re-derives each move locally (apply named pit → exact position
  match). Mismatch → move rejected, room left
- Network **pass** support (`pit == -1`, only when no legal move)
- Anonymous Firebase auth (falls back to a local stub identity)
- `database.rules.json` — per-UID guards, shape validation
- Tests: create→join, bad code, full room, out-of-turn rejection,
  illegal-pit rejection, fake-pass rejection, full match over the backend

### Phase 4 — Monetization (ads only)
- `AdService` seam: `MobileAdService` (Android/iOS) vs `NoopAdService`
  (web/desktop) — selected via `defaultTargetPlatform`, no `dart:io`
- Banner on home hub; **interstitial after every 2nd finished match**,
  never mid-turn
- Ships with Google's **test** ad units; swap via
  `--dart-define=ADMOB_*` (see `config/README.md`)
- Manifest AdMob APPLICATION_ID (test id) — note XML comments cannot
  contain `--`

### Phase 5 — Ship prep
- `README.md` (product + architecture), `config/README.md` (Firebase,
  AdMob, profiles), `docs/RULESETS.md` (rules + review checklist)
- Both release artifacts verified:
  - `flutter build web --release` → `build/web/`
  - `flutter build apk --debug` → `build/app/outputs/flutter-apk/`

---

## Test inventory (39)

| Suite | Covers |
|---|---|
| `test/features/game/game_engine_test.dart` | sowing, capture chains, starvation, give-seeds, pass/end/result, stalemate, 200-game conservation |
| `test/features/game/ai_engine_test.dart` | legal choices, pass detection, capture greed, hard timing, hard-beats-easy series, self-play termination |
| `test/features/game/game_controller_test.dart` | newGame flow, AI reply, illegal-tap ignore, full match + stat recording |
| `test/features/multiplayer/room_flow_test.dart` | room lifecycle, turn enforcement, illegal pits, pass rules, full online match |
| `test/widget_test.dart` | home hub renders |

---

## Remaining setup (all free, ~30 min)

1. **Rules review** — play vs the computer, tick off `docs/RULESETS.md`
   TODOs (corrections live in one file: `game_engine.dart`)
2. **Firebase** (real cross-device play): `firebase login` →
   `flutterfire configure` → `firebase deploy --only database:rules`
3. **AdMob** (real revenue): free account at apps.admob.com → replace
   manifest APPLICATION_ID → pass real units at build time
4. **Distribute**:
   - Web: deploy `build/web` to Firebase Hosting (Spark) or Vercel
   - APK: GitHub Release / direct download from the same host
   - Play Store ($25) only later if store distribution is worth it

## Roadmap

- Turn timers + reconnect grace online
- Pass-and-play local mode
- Leaderboards (Firebase, stays on free tier)
- **Satr / Shambat** — expand to the "hub" (rules must be taught; none
  exist online)
