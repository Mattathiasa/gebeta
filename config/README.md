# Build profiles & runtime flags

## Firebase (optional — the app runs without it)

Online play needs a Firebase project on the **Spark (free) plan**:

```bash
npm i -g firebase-tools
firebase login
flutterfire configure          # regenerates lib/firebase_options.dart
firebase deploy --only database:rules   # uses database.rules.json
```

Until then the app boots in stub mode: AI play, tutorial, and stats all
work; the lobby uses the in-memory stub (great for UI dev, not for real
matches across devices).

## AdMob (Android only — web is intentionally ad-free)

The build ships with Google's **test** ad units. Before publishing:

1. Create an AdMob app (free) at https://apps.admob.com
2. Replace the APPLICATION_ID in `android/app/src/main/AndroidManifest.xml`
3. Create banner + interstitial units and pass them at build time:

```bash
flutter build apk --release \
  --dart-define=ADMOB_BANNER_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_INTERSTITIAL_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
```

Never click your own ads.

## Profiles via run_flutter_app.sh

```bash
../run_flutter_app.sh gebeta run -d chrome   # from the Projects root
../run_flutter_app.sh gebeta run             # default device
```
