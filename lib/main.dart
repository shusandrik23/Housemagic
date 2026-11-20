import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'REPLACE_ME') {
      runApp(const FirebaseSetupScreen(details: 'Нет ключей для этой платформы.'));
      return;
    }
    await Firebase.initializeApp(options: options);
  } catch (e) {
    runApp(FirebaseSetupScreen(details: '$e'));
    return;
  }
  runApp(CleanPageApp(services: AppServices.firebase()));
}
