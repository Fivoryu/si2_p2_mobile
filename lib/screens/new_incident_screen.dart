import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/local_db.dart';
import '../data/models/vehiculo.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';

class NewIncidentScreen extends ConsumerStatefulWidget {
  const NewIncidentScreen({super.key});

  @override
  ConsumerState<NewIncidentScreen> createState() => _NewIncidentScreenState();
}

class _NewIncidentScreenState extends ConsumerState<NewIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String? _selectedVehicleId;
  List<XFile> _photos = [];
  bool _saving = false;
  String? _savedIdLocal;
  bool _pendingSync = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _buildEvidencias() async {
    final evidencias = <Map<String, dynamic>>[];
    for (final photo in _photos) {
      final bytes = await File(photo.path).readAsBytes();
      evidencias.add({
        'tipo': 'IMAGEN',
        'contenido_base64': base64Encode(bytes),
        'nombre': photo.name,
      });
    }
    return evidencias;
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() => _photos = [..._photos, ...picked]);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un vehículo')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final idLocal = const Uuid().v4();
      final pos = await LocationService.current();
      final address = await LocationService.addressFromPosition(pos);
      final evidencias = await _buildEvidencias();
      final now = DateTime.now().toUtc().toIso8601String();

      final row = {
        'id_local': idLocal,
        'vehiculo_id': _selectedVehicleId,
        'descripcion': _descCtrl.text.trim(),
        'latitud': pos.latitude,
        'longitud': pos.longitude,
        'direccion': address,
        'evidencias': jsonEncode(evidencias),
        'estado_sync': 'PENDIENTE',
        'client_created_at': now,
        'client_updated_at': now,
      };

      await LocalDb.insertPending(row);

      var pending = true;
      if (await SyncService.hasConnectivity()) {
        await SyncService.syncNow();
        final updated = await LocalDb.allLocal();
        final saved = updated.firstWhere((r) => r['id_local'] == idLocal);
        pending = saved['estado_sync'] == 'PENDIENTE';
      }

      ref.invalidate(incidentesProvider);

      if (!mounted) return;
      setState(() {
        _savedIdLocal = idLocal;
        _pendingSync = pending;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                pending ? Icons.schedule : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pending
                      ? 'Guardado localmente, se sincronizará'
                      : 'Incidente sincronizado con el servidor',
                ),
              ),
            ],
          ),
        ),
      );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva emergencia')),
      body: vehiculosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vehiculos) {
          if (vehiculos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Vehículo'),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del problema',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.photo_camera),
                    label: Text('Fotos (${_photos.length})'),
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() => _photos.removeAt(index));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                  if (_savedIdLocal != null) ...[
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(
                        _pendingSync ? Icons.schedule : Icons.cloud_done,
                        color: _pendingSync ? Colors.orange : Colors.green,
                      ),
                      title: Text(
                        _pendingSync
                            ? 'Pendiente de sincronización'
                            : 'Sincronizado',
                      ),
                      subtitle: Text('ID local: $_savedIdLocal'),
                      trailing: _pendingSync
                          ? null
                          : TextButton(
                              onPressed: () {
                                context.push('/tracking/$_savedIdLocal');
                              },
                              child: const Text('Seguir'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
