import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../core/api_errors.dart';
import '../data/local_db.dart';
import '../data/models/vehiculo.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../shared/widgets/location_map.dart';

class NewIncidentScreen extends ConsumerStatefulWidget {
  const NewIncidentScreen({super.key});

  @override
  ConsumerState<NewIncidentScreen> createState() => _NewIncidentScreenState();
}

class _NewIncidentScreenState extends ConsumerState<NewIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();

  String? _selectedVehicleId;
  List<XFile> _photos = [];
  String? _audioPath;
  Duration _audioDuration = Duration.zero;
  bool _recording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  bool _saving = false;

  Position? _position;
  String? _address;
  bool _loadingLocation = true;
  String? _locationError;

  String? _audioTranscript;
  String? _iaCodigo;
  double? _iaConfianza;
  bool _analyzingPhoto = false;
  bool _transcribingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final pos = await LocationService().current();
      final address = await LocationService.addressFromPosition(pos);
      if (mounted) {
        setState(() {
          _position = pos;
          _address = address;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _loadingLocation = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildEvidencias() async {
    final evidencias = <Map<String, dynamic>>[];
    for (final photo in _photos) {
      final bytes = await File(photo.path).readAsBytes();
      evidencias.add({
        'tipo': 'IMAGEN',
        'contenido_b64': base64Encode(bytes),
        'mime_type': 'image/jpeg',
        'nombre': photo.name,
      });
    }
    if (_audioPath != null) {
      final bytes = await File(_audioPath!).readAsBytes();
      evidencias.add({
        'tipo': 'AUDIO',
        'contenido_b64': base64Encode(bytes),
        'mime_type': 'audio/aac',
        'texto': _audioTranscript ??
            (_descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null),
      });
    }
    return evidencias;
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(imageQuality: 70);
      if (picked.isNotEmpty) {
        setState(() => _photos = [..._photos, ...picked]);
        await _analyzeLatestPhoto();
      }
    } else {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() => _photos = [..._photos, picked]);
        await _analyzeLatestPhoto();
      }
    }
  }

  void _applyDescripcion(String text, {bool append = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!append || _descCtrl.text.trim().isEmpty) {
      _descCtrl.text = trimmed;
    } else if (!_descCtrl.text.contains(trimmed)) {
      _descCtrl.text = '${_descCtrl.text.trim()}\n$trimmed';
    }
  }

  Future<void> _analyzeLatestPhoto() async {
    if (_photos.isEmpty) return;
    if (!await SyncService.hasConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión: no se pudo analizar la foto con IA'),
        ),
      );
      return;
    }

    setState(() => _analyzingPhoto = true);
    try {
      final file = File(_photos.last.path);
      final result = await ref.read(iaApiProvider).clasificarImagen(file);
      if (!mounted) return;
      setState(() {
        _iaCodigo = result.codigo;
        _iaConfianza = result.confianza;
      });
      _applyDescripcion(result.descripcion);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'IA: ${result.codigo} (${(result.confianza * 100).round()}%)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Análisis de imagen: ${messageFromDio(e)}')),
      );
    } finally {
      if (mounted) setState(() => _analyzingPhoto = false);
    }
  }

  Future<void> _transcribeRecordedAudio() async {
    if (_audioPath == null) return;
    if (!await SyncService.hasConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión: no se pudo transcribir el audio'),
        ),
      );
      return;
    }

    setState(() => _transcribingAudio = true);
    try {
      final result =
          await ref.read(iaApiProvider).transcribirAudio(File(_audioPath!));
      if (!mounted) return;
      setState(() => _audioTranscript = result.texto);
      _applyDescripcion(result.texto, append: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio transcrito a texto')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transcripción: ${messageFromDio(e)}')),
      );
    } finally {
      if (mounted) setState(() => _transcribingAudio = false);
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de micrófono denegado')),
      );
      return;
    }
    final path =
        '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordSeconds = 0;
      _audioPath = path;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
        _audioDuration = Duration(seconds: _recordSeconds);
      });
      if (_recordSeconds >= 60) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (_recording) {
      await _recorder.stop();
    }
    if (mounted) {
      setState(() => _recording = false);
      await _transcribeRecordedAudio();
    }
  }

  void _removeAudio() {
    if (_audioPath != null) {
      File(_audioPath!).delete().ignore();
    }
    setState(() {
      _audioPath = null;
      _audioTranscript = null;
      _audioDuration = Duration.zero;
      _recordSeconds = 0;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un vehículo')),
      );
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación GPS requerida')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_recording) await _stopRecording();

      final idLocal = const Uuid().v4();
      final evidencias = await _buildEvidencias();
      final now = DateTime.now().toUtc().toIso8601String();

      final row = {
        'id_local': idLocal,
        'vehiculo_id': _selectedVehicleId,
        'descripcion': _descCtrl.text.trim(),
        'latitud': _position!.latitude,
        'longitud': _position!.longitude,
        'direccion': _address,
        'evidencias': jsonEncode(evidencias),
        'estado_sync': 'PENDIENTE',
        'client_created_at': now,
        'client_updated_at': now,
      };

      await LocalDb.insertPending(row);

      var pending = true;
      if (await SyncService.hasConnectivity()) {
        try {
          final descText = _descCtrl.text.trim();
          if (descText.isNotEmpty && mounted) {
            try {
              final iaResult = await ref.read(iaApiProvider).clasificarTexto(descText);
              if (mounted) {
                setState(() {
                  _iaCodigo = iaResult.codigo;
                  _iaConfianza = iaResult.confianza;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('IA texto: ${iaResult.codigo} (${(iaResult.confianza * 100).round()}%)'),
                  ),
                );
              }
            } catch (_) {}
          }
          await SyncService.syncNow();
          final updated = await LocalDb.allLocal();
          final saved = updated.firstWhere((r) => r['id_local'] == idLocal);
          pending = saved['estado_sync'] == 'PENDIENTE';
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(messageFromDio(e))),
            );
          }
        }
      }

      ref.invalidate(incidentesProvider);

      if (!mounted) return;
      setState(() => _saving = false);

      final message = pending
          ? 'Emergencia registrada. Se enviará al servidor cuando haya conexión.'
          : 'Emergencia recibida correctamente. Pronto le atenderemos.';

      context.go('/home', extra: message);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiculosAsync = ref.watch(vehiculosProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva emergencia')),
      body: vehiculosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final unauthorized = isUnauthorizedError(e);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    unauthorized ? Icons.lock_clock : Icons.cloud_off,
                    size: 56,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    unauthorized
                        ? 'Sesión expirada'
                        : 'Sin conexión al servidor',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    messageFromDio(e),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (unauthorized)
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Iniciar sesión'),
                    )
                  else
                    FilledButton(
                      onPressed: () => ref.invalidate(vehiculosProvider),
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            ),
          );
        },
        data: (vehiculos) {
          if (vehiculos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text('Registre un vehículo primero'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/vehicles'),
                    child: const Text('Ir a vehículos'),
                  ),
                ],
              ),
            );
          }

          _selectedVehicleId ??= vehiculos.first.id;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 56,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reportar emergencia',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Describa el problema y adjunte evidencias. '
                      'Se guardará localmente si no hay conexión.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Vehículo',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                      items: vehiculos
                          .map(
                            (Vehiculo v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedVehicleId = v),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ubicación',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: _loadingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Obteniendo GPS…'),
                                ],
                              ),
                            )
                          : _locationError != null
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_off,
                                            color: colorScheme.error,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_locationError!),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: _loadLocation,
                                        child: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    LocationMap(
                                      latitude: _position!.latitude,
                                      longitude: _position!.longitude,
                                      height: 160,
                                      borderRadius: 0,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.my_location,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _address ??
                                                      'Ubicación obtenida',
                                                  style: theme
                                                      .textTheme.bodyMedium,
                                                ),
                                                Text(
                                                  '${_position!.latitude.toStringAsFixed(5)}, '
                                                  '${_position!.longitude.toStringAsFixed(5)}',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Descripción del problema',
                        hintText: 'Ej. Motor no enciende, humo bajo el capó…',
                        prefixIcon: const Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                        suffixIcon: _analyzingPhoto || _transcribingAudio
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                        helperText: _analyzingPhoto
                            ? 'Analizando foto con IA…'
                            : _transcribingAudio
                                ? 'Transcribiendo audio…'
                                : 'Se completa automáticamente con foto o audio',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    if (_iaCodigo != null && _iaConfianza != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            'IA imagen: $_iaCodigo '
                            '(${(_iaConfianza! * 100).round()}%)',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Fotos',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _pickPhotos(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text('Galería (${_photos.length})'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhotos(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Cámara'),
                          ),
                        ),
                      ],
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, a) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_photos[index].path),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.black54,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(28, 28),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() {
                                      _photos.removeAt(index);
                                      if (_photos.isEmpty) {
                                        _iaCodigo = null;
                                        _iaConfianza = null;
                                      }
                                    }),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Audio (máx. 60 s)',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _recording ? Icons.mic : Icons.mic_none,
                              color: _recording
                                  ? colorScheme.error
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _audioPath == null
                                    ? 'Sin grabación'
                                    : _recording
                                        ? 'Grabando ${_formatDuration(_audioDuration)}'
                                        : 'Audio ${_formatDuration(_audioDuration)}',
                              ),
                            ),
                            if (_audioPath != null && !_recording)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _removeAudio,
                              ),
                            FilledButton.tonal(
                              onPressed: _recording
                                  ? _stopRecording
                                  : _startRecording,
                              child: Text(_recording ? 'Detener' : 'Grabar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reportar emergencia'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
