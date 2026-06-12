import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database_init.dart';
import 'core/dio_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'core/app_messenger.dart';
import 'providers/app_providers.dart';
import 'services/in_app_notification_service.dart';
import 'services/local_notification_service.dart';
import 'services/push_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSqflite();
  if (!kIsWeb || DefaultFirebaseOptions.webOrNull != null) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await LocalNotificationService.init();
  }
  SyncService.start();
  runApp(const ProviderScope(child: EmergenciasApp()));
}

class EmergenciasApp extends ConsumerStatefulWidget {
  const EmergenciasApp({super.key});

  @override
  ConsumerState<EmergenciasApp> createState() => _EmergenciasAppState();
}

class _EmergenciasAppState extends ConsumerState<EmergenciasApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncService.addListener((_) {
      ref.invalidate(incidentesProvider);
    });
    registerUnauthorizedHandler(() async {
      invalidateAuthProviders(ref);
    });
    _initPushIfLoggedIn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService.syncNow().then((n) {
        if (n > 0) ref.invalidate(incidentesProvider);
      });
    }
  }

  Future<void> _initPushIfLoggedIn() async {
    if (!await ref.read(authServiceProvider).isLoggedIn()) return;
    final dio = ref.read(dioProvider);
    await PushService.init(dio);
    LocalNotificationService.attachRouter(ref.read(routerProvider));
    InAppNotificationService.attachRouter(ref.read(routerProvider));
    InAppNotificationService.start(dio);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    LocalNotificationService.attachRouter(router);
    InAppNotificationService.attachRouter(router);

    return MaterialApp.router(
      title: 'Emergencias Vial',
      theme: AppTheme.light,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
