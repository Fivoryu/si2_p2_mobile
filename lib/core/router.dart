import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/incidente.dart';
import '../core/config.dart';
import '../providers/app_providers.dart';
import '../screens/asignacion_detail_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/incident_detail_screen.dart';
import '../screens/login_screen.dart';
import '../screens/new_incident_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_tecnico_screen.dart';
import '../screens/taller_home_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/vehicle_form_screen.dart';
import '../screens/vehicles_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) async {
      final loggedIn = authAsync.when<bool?>(
        data: (v) => v,
        loading: () => null,
        error: (e, s) => false,
      );
      if (loggedIn == null) return null;

      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onPasswordChange = state.matchedLocation == '/change-password';

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) {
        // Check if must change password before going to home
        final mustChange = await ref.read(authServiceProvider).getMustChangePassword();
        if (mustChange) return '/change-password';
        final rol = await ref.read(authServiceProvider).getRol();
        return Config.homeRouteForRol(rol);
      }
      if (loggedIn && !onPasswordChange) {
        final mustChange = await ref.read(authServiceProvider).getMustChangePassword();
        if (mustChange) return '/change-password';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
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
        path: '/taller-home',
        builder: (context, state) => const TallerHomeScreen(),
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
        path: '/incident/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final local = state.extra as Incidente?;
          return IncidentDetailScreen(
            incidentId: id,
            localIncident: local,
          );
        },
      ),
      GoRoute(
        path: '/asignacion/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AsignacionDetailScreen(asignacionId: id);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const VehicleFormScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/tecnico',
        builder: (context, state) => const SettingsTecnicoScreen(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(authStateProvider, (_, a) => notifyListeners());
    ref.listen(loginProvider, (_, b) => notifyListeners());
  }

  final Ref ref;
}
