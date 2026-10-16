import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/game/presentation/ai_game_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/multiplayer/presentation/lobby_screen.dart';
import '../../features/multiplayer/presentation/online_game_screen.dart';
import '../../features/tutorial/presentation/tutorial_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.tutorial,
        builder: (_, _) => const TutorialScreen(),
      ),
      GoRoute(
        path: Routes.gameAi,
        builder: (_, _) => const AiGameScreen(),
      ),
      GoRoute(
        path: Routes.lobby,
        builder: (_, _) => const LobbyScreen(),
      ),
      GoRoute(
        path: Routes.gameOnline,
        builder: (_, state) => OnlineGameScreen(
          code: state.uri.queryParameters['code'] ?? '',
        ),
      ),
    ],
  );
});
