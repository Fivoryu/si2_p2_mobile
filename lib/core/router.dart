import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/new_incident_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/vehicles_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final loggedIn = authAsync.when<bool?>(
        data: (v) => v,
        loading: () => null,
        error: (_, __) => false,
      );
      if (loggedIn == null) return null;

      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/new-incident',
        builder: (context, state) => const NewIncidentScreen(),
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TrackingScreen(incidentId: id);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
