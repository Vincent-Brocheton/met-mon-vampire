import 'package:web/web.dart' as web;

/// Recharge l'app sur [location] : l'instance Firestore arrêtée ne peut pas resservir.
Future<void> reloadAt(String location) async => web.window.location.assign(location);
