import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';import 'package:go_router/go_router.dart';

import '../core/app_messenger.dart';
import 'local_notification_service.dart';

class InAppNotificationService {
  InAppNotificationService._();

  static Timer? _timer;
  static final Set<String> _seenIds = {};
  static bool _bootstrapped = false;
  static GoRouter? _router;

  static void attachRouter(GoRouter router) {
    _router = router;
  }

  static void start(Dio dio) {
    _timer?.cancel();
    _poll(dio);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _poll(dio));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _bootstrapped = false;
    _seenIds.clear();
  }

  static Future<void> _poll(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/usuarios/me/notificaciones',
      );
      final items = response.data?['items'] as List<dynamic>? ?? [];

      if (!_bootstrapped) {
        for (final raw in items) {
          final id = (raw as Map<String, dynamic>)['id']?.toString();
          if (id != null) _seenIds.add(id);
        }
        _bootstrapped = true;
        return;
      }

      final nuevas = <Map<String, dynamic>>[];
      for (final raw in items) {
        final m = raw as Map<String, dynamic>;
        final id = m['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;
        _seenIds.add(id);
        nuevas.add(m);
      }

      for (final n in nuevas.reversed) {
        showFromPayload(n);
      }
    } catch (_) {
      // sin sesión o sin permiso
    }
  }

  static void showFromPayload(Map<String, dynamic> data) {
    final title = data['titulo'] as String? ?? 'Notificación';
    final body = data['mensaje'] as String? ?? '';
    final incidenteId = data['incidente_id'] as String?;
    show(title: title, body: body, incidenteId: incidenteId);
  }

  static void show({
    required String title,
    required String body,
    String? incidenteId,
  }) {
    if (LocalNotificationService.supported) {
      LocalNotificationService.show(
        title: title,
        body: body,
        incidenteId: incidenteId,
      );
      return;
    }

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body),
            ],
          ],
        ),
        action: incidenteId != null && _router != null
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => _router!.push('/tracking/$incidenteId'),
              )
            : null,
      ),
    );
  }
}
