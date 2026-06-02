import 'dart:io';

import 'package:dio/dio.dart';

class IaClasificacion {
  IaClasificacion({
    required this.codigo,
    required this.confianza,
    required this.descripcion,
    required this.prioridadSugerida,
    this.etiqueta,
    this.fuente,
    this.modelo,
  });

  final String codigo;
  final double confianza;
  final String descripcion;
  final String prioridadSugerida;
  final String? etiqueta;
  final String? fuente;
  final String? modelo;

  factory IaClasificacion.fromJson(Map<String, dynamic> json) {
    return IaClasificacion(
      codigo: json['codigo'] as String,
      confianza: (json['confianza'] as num).toDouble(),
      descripcion: json['descripcion'] as String,
      prioridadSugerida: json['prioridad_sugerida'] as String,
      etiqueta: json['etiqueta'] as String?,
      fuente: json['fuente'] as String?,
      modelo: json['modelo'] as String?,
    );
  }
}

class IaTranscripcion {
  IaTranscripcion({required this.texto, required this.motor});

  final String texto;
  final String motor;

  factory IaTranscripcion.fromJson(Map<String, dynamic> json) {
    return IaTranscripcion(
      texto: json['transcripcion'] as String,
      motor: json['motor'] as String,
    );
  }
}

class IaApi {
  IaApi(this._dio);

  final Dio _dio;

  Future<IaClasificacion> clasificarImagen(File file) async {
    final bytes = await file.readAsBytes();
    final name = file.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: name),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/ia/clasificar-imagen',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      ),
    );
    return IaClasificacion.fromJson(response.data!);
  }

  Future<IaTranscripcion> transcribirAudio(File file) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'audio.m4a',
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/ia/transcribir-audio',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      ),
    );
    return IaTranscripcion.fromJson(response.data!);
  }

  Future<IaClasificacion> clasificarTexto(String texto) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ia/clasificar-texto',
      data: {'texto': texto},
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return IaClasificacion.fromJson(response.data!);
  }
}
