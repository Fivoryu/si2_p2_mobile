import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/vehiculo.dart';
import '../providers/app_providers.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  Future<void> _showAddDialog() async {
    final placaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final anioCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo vehículo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: placaCtrl,
                decoration: const InputDecoration(labelText: 'Placa *'),
              ),
              TextField(
                controller: marcaCtrl,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
              TextField(
                controller: modeloCtrl,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              TextField(
                controller: anioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Año'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || placaCtrl.text.trim().isEmpty) {
      placaCtrl.dispose();
      marcaCtrl.dispose();
      modeloCtrl.dispose();
      anioCtrl.dispose();
      return;
    }

    try {
      await ref.read(vehiculoApiProvider).create(
            Vehiculo(
              id: '',
              placa: placaCtrl.text.trim().toUpperCase(),
              marca: marcaCtrl.text.trim().isEmpty
                  ? null
                  : marcaCtrl.text.trim(),
              modelo: modeloCtrl.text.trim().isEmpty
                  ? null
                  : modeloCtrl.text.trim(),
              anio: int.tryParse(anioCtrl.text.trim()),
            ),
          );
      ref.invalidate(vehiculosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo registrado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      placaCtrl.dispose();
      marcaCtrl.dispose();
      modeloCtrl.dispose();
      anioCtrl.dispose();
    }
  }

  Future<void> _delete(Vehiculo v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text('¿Eliminar ${v.placa}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(vehiculoApiProvider).delete(v.id);
      ref.invalidate(vehiculosProvider);
    } catch (e) {
      if (mounted) {
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
      appBar: AppBar(title: const Text('Mis vehículos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: vehiculosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No tiene vehículos registrados'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final v = items[index];
              return ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(v.placa),
                subtitle: Text(v.label),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(v),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
