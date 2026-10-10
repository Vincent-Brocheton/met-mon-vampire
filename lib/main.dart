import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'offline/wipe.dart';
import 'router.dart';

/// `--dart-define=EMULATORS=true` pour travailler sur les émulateurs locaux.
const useEmulators = bool.fromEnvironment('EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Effacement raté lors de la session précédente (autre onglet ouvert, par exemple) : repris avant de démarrer l'instance.
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(wipePendingKey)) {
    try {
      await FirebaseFirestore.instance.clearPersistence();
      await prefs.remove(wipePendingKey);
    } catch (e) {
      debugPrint('Effacement du cache repris au démarrage : échec ($e)');
    }
  }
  // Hors ligne (8c) : cache persistant, partagé entre onglets sur le Web (IndexedDB), réglé avant toute lecture.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  if (useEmulators) {
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  runApp(const ProviderScope(child: PortailApp()));
}

class PortailApp extends ConsumerWidget {
  const PortailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Portail MET',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      );
}
