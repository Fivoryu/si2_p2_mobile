import 'dart:async';

import '../data/api/incidente_api.dart';
import '../data/models/asignacion.dart';
import 'location_service.dart';

/// Envía periódicamente la ubicación del técnico (real o simulada) al backend.
class TechnicianLocationBroadcaster {
  TechnicianLocationBroadcaster._();
  static final instance = TechnicianLocationBroadcaster._();

  Timer? _timer;
  IncidenteApi? _api;
  List<Asignacion> Function()? _getAssignments;

  void configure({
    required IncidenteApi api,
    required List<Asignacion> Function() getAssignments,
  }) {
    _api = api;
    _getAssignments = getAssignments;
  }

  void syncWithAssignments(List<Asignacion> assignments) {
    if (_hasActiveTracking(assignments)) {
      start();
    } else {
      stop();
    }
  }

  bool _hasActiveTracking(List<Asignacion> assignments) {
    return assignments.any(
      (a) =>
          !a.esCandidato &&
          a.estado == 'ACEPTADO' &&
          a.incidenteEstado == 'TALLER_ASIGNADO',
    );
  }

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => sendNow());
    sendNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> sendNow() async {
    final api = _api;
    final getAssignments = _getAssignments;
    if (api == null || getAssignments == null) return;

    final active = getAssignments().where(
      (a) =>
          !a.esCandidato &&
          a.estado == 'ACEPTADO' &&
          a.incidenteEstado == 'TALLER_ASIGNADO',
    );
    if (active.isEmpty) return;

    final loc = LocationService();
    try {
      final pos = await loc.current();
      for (final a in active) {
        if (a.incidenteId.isEmpty) continue;
        await api.enviarUbicacion(
          a.incidenteId,
          lat: pos.latitude,
          lng: pos.longitude,
          esFake: loc.usarFakeGps,
        );
      }
    } catch (_) {
      // offline o sin permiso — reintentará en el próximo tick
    }
  }
}
