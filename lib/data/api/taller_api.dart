import 'package:dio/dio.dart';

import '../models/asignacion.dart';

class TallerApi {
  TallerApi(this._dio);

  final Dio _dio;

  Future<List<Asignacion>> misAsignaciones({String? estado}) async {
    final query = <String, dynamic>{};
    if (estado != null) query['estado'] = estado;
    final response = await _dio.get<Map<String, dynamic>>(
      '/talleres/asignaciones',
      queryParameters: query,
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => Asignacion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Asignacion> getAsignacion(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/asignaciones/$id');
    return Asignacion.fromJson(response.data!);
  }

  Future<void> aceptar(String asignacionId, {String? tecnicoId}) async {
    await _dio.post<Map<String, dynamic>>(
      '/asignaciones/$asignacionId/aceptar',
      data: {'tecnico_id': tecnicoId},
    );
  }

  Future<void> aceptarConOferta(
    String asignacionId, {
    double? precioOfertado,
    int? tiempoEstimadoMin,
    String? tecnicoId,
    String? comentario,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/asignaciones/$asignacionId/aceptar-con-oferta',
      data: {
        'precio_ofertado': precioOfertado,
        'tiempo_estimado_min': tiempoEstimadoMin,
        'tecnico_id': tecnicoId,
        'comentario': comentario,
      },
    );
  }

  Future<void> rechazar(String asignacionId, {String? motivo}) async {
    await _dio.post<Map<String, dynamic>>(
      '/asignaciones/$asignacionId/rechazar',
      data: {'motivo': motivo},
    );
  }

  Future<void> actualizarDisponibilidad(bool disponible) async {
    await _dio.put<Map<String, dynamic>>(
      '/talleres/disponibilidad',
      data: {'disponible': disponible},
    );
  }

  Future<List<Map<String, dynamic>>> misNotificaciones() async {
    final response = await _dio.get<Map<String, dynamic>>('/talleres/notificaciones');
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  // -------- Candidatos (incidentes sin asignar donde este taller es candidato) --------

  Future<void> aceptarCandidato(
    String candidatoId, {
    double? precioOfertado,
    int? tiempoEstimadoMin,
    String? tecnicoId,
    String? comentario,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/talleres/candidatos/$candidatoId/aceptar',
      data: {
        'precio_ofertado': precioOfertado,
        'tiempo_estimado_min': tiempoEstimadoMin,
        'tecnico_id': tecnicoId,
        'comentario': comentario,
      },
    );
  }

  Future<void> rechazarCandidato(
    String candidatoId, {
    String? motivo,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/talleres/candidatos/$candidatoId/rechazar',
      data: {'motivo': motivo},
    );
  }
}
