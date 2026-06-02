import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dio_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SyncService.start();
  runApp(const ProviderScope(child: EmergenciasApp()));
}

class EmergenciasApp extends ConsumerStatefulWidget {
  const EmergenciasApp({super.key});

  @override
  ConsumerState<EmergenciasApp> createState() => _EmergenciasAppState();
}

class _EmergenciasAppState extends ConsumerState<EmergenciasApp> {
  @override
  void initState() {
    super.initState();
    registerUnauthorizedHandler(() async {
      invalidateAuthProviders(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Emergencias Vial',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
