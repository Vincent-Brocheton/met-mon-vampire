import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Options factices du projet `demo-portail-met` : ne fonctionnent qu'avec
/// les émulateurs. Remplacé par `flutterfire configure` (tâche 16).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: kIsWeb
            ? '1:000000000000:web:0000000000000000'
            : '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-portail-met',
      );
}
