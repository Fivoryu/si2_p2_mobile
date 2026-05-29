import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SyncService.start();
  runApp(const ProviderScope(child: EmergenciasApp()));
}

class EmergenciasApp extends ConsumerWidget {
  const EmergenciasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Emergencias Vial',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
