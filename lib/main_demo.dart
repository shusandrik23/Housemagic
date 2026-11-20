import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'demo/demo_backend.dart';

/// Демо-сборка: без Firebase, данные в памяти вкладки.
///   flutter build web -t lib/main_demo.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await DemoBackend.create();
  runApp(
    CleanPageApp(
      services: services,
      demoNote:
          'Демо-версия · данные живут только в этой вкладке · '
          'PIN родителя: ${DemoBackend.parentPin}',
    ),
  );
}
