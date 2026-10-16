# ገበጣ · Gebeta Online

**[Play it live](https://mattathiasa.github.io/gebeta/play/)** ·
[How to play](https://mattathiasa.github.io/gebeta/help/) ·
[Landing page](https://mattathiasa.github.io/gebeta/)

![tests](https://img.shields.io/badge/tests-39%2F39%20passing-2E7D32)
![analyze](https://img.shields.io/badge/flutter%20analyze-clean-2E7D32)
![license](https://img.shields.io/badge/license-MIT-B8860B)

A polished digital implementation of **Gebeta**, the traditional Ethiopian
and Eritrean mancala game — built to keep a living game playable for the
diaspora, and to be a portfolio-grade Flutter codebase.

- **Play vs computer** — three difficulties (minimax + alpha-beta, hard
  runs its search in a background isolate)
- **Play online** — private 4-letter room codes, RTDB-backed, with
  client-side dual-compute move validation
- **EN / አማ** — fully localized, bundled NotoSansEthiopic
- **Web + Android** — one codebase; web ships ad-free, Android carries
  AdMob (test ads until configured)
- **100% free stack** — Firebase Spark plan, no billing account, no
  paid services anywhere

## Run it

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # connected Android device
flutter test                 # 39 tests: engine, AI, controller, rooms
```

From the workspace root you can also `./run_flutter_app.sh gebeta run`.

The app runs **without any Firebase setup** (stub mode). Online play
across devices needs `flutterfire configure` — see `config/README.md`.

## Architecture

```
lib/
  core/           theme, router, auth, ads, Firebase bootstrap
  features/
    game/         pure-Dart engine + AI + controller + board UI
    multiplayer/  rooms, lobby, RTDB/stub repositories, dual-compute
    stats/        on-device lifetime record
    tutorial/     3-step interactive rules
  shared/widgets/ banner ad (Android only)
```

Key properties:

- **The engine is pure Dart** (`features/game/domain/game_engine.dart`)
  with zero Flutter imports — unit-tested with capture-chain cases,
  starvation rules, and 200 randomized games asserting seed conservation.
- **No server runtime.** Cloud Functions require a billing account, so
  every move is validated twice: the writer checks turn + legality in an
  RTDB transaction, and every client re-derives the position
  (dual-compute, the pattern from `fan-battle-arena`). A mismatch
  rejects the move and leaves the room.
- **Rules live in one file.** Gebeta has regional variants; the
  implemented "classic" 12-pit ruleset is documented in
  `docs/RULESETS.md` for review.

## Monetization

Ads only (per product decision): a banner on the home hub and an
interstitial after every second finished AI match — never mid-turn.
Web is deliberately ad-free. Setup: `config/README.md`.

## Distributing without the Play Store (free)

1. **Web**: `flutter build web --release` → deploy `build/web` to
   Firebase Hosting (Spark free tier) or Vercel.
2. **Android APK**: `flutter build apk --release` → attach to a GitHub
   Release or serve the file from the same host; users sideload.
3. Optional later: Play Console ($25 once) if store distribution
   becomes worth it.

## Roadmap

- [ ] Rules review with a native player (docs/RULESETS.md TODOs)
- [ ] Satr and Shambat as the "hub" expands
- [ ] Turn timers + reconnect grace for online play
- [ ] Pass-and-play local mode
- [ ] Leaderboards (needs Firebase config; stays on free tier)

## License

MIT — see [LICENSE](LICENSE).
