import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime record kept on-device. No accounts, no cloud — this is a
/// vanity counter, not an anti-cheat ledger.
class PlayerStats {
  const PlayerStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  PlayerStats copyWith({
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
  }) =>
      PlayerStats(
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
      );

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
      };

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
      );
}

abstract final class StatsStore {
  static const _key = 'gebeta.player_stats';

  static Future<PlayerStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PlayerStats();
    try {
      return PlayerStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerStats();
    }
  }

  static Future<PlayerStats> record({
    required int result, // 1 win, -1 loss, 0 draw
  }) async {
    final current = await load();
    final updated = current.copyWith(
      gamesPlayed: current.gamesPlayed + 1,
      wins: current.wins + (result > 0 ? 1 : 0),
      losses: current.losses + (result < 0 ? 1 : 0),
      draws: current.draws + (result == 0 ? 1 : 0),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.toJson()));
    return updated;
  }
}
