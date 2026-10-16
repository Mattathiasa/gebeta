import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stats_store.dart';

/// Lifetime on-device record. Invalidated by the game controller after
/// each match so the home hub stays current.
final playerStatsProvider = FutureProvider<PlayerStats>((ref) {
  return StatsStore.load();
});
