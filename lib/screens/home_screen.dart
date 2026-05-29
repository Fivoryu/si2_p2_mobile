import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../services/location_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Position? _position;
  String? _locationError;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final pos = await LocationService.current();
      if (mounted) {
        setState(() {
          _position = pos;
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () => context.push('/vehicles'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            profileAsync.when(
              data: (u) => Text(
                'Hola, ${u?.nombre ?? 'Conductor'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Conductor'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loadingLocation
                      ? const Center(child: CircularProgressIndicator())
                      : _locationError != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_off, size: 48),
                                const SizedBox(height: 8),
                                Text(_locationError!),
                                TextButton(
                                  onPressed: _loadLocation,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.my_location, size: 64),
                                const SizedBox(height: 12),
                                Text(
                                  'Ubicación actual',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_position!.latitude.toStringAsFixed(5)}, '
                                  '${_position!.longitude.toStringAsFixed(5)}',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/new-incident'),
              icon: const Icon(Icons.add_alert),
              label: const Text('Nueva emergencia'),
            ),
          ],
        ),
      ),
    );
  }
}
