import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/auth/household_choice_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/create_household_screen.dart';
import 'services/app_services.dart';
import 'state/session_controller.dart';
import 'widgets/notebook.dart';

class CleanPageApp extends StatelessWidget {
  const CleanPageApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            auth: services.auth,
            users: services.users,
            households: services.households,
            children: services.children,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Чистый Лист',
        debugShowCheckedModeBanner: false,
        theme: buildNotebookTheme(),
        home: const RootSwitch(),
      ),
    );
  }
}

/// Выбирает экран по стадии сессии (auto-login: FirebaseAuth сам
/// восстанавливает сессию, и сюда сразу приходит пользователь).
class RootSwitch extends StatelessWidget {
  const RootSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return switch (session.stage) {
      SessionStage.loading => const _Splash(),
      SessionStage.signedOut => const SignInScreen(),
      SessionStage.needsHousehold => const HouseholdChoiceScreen(),
      SessionStage.needsSetup => CreateHouseholdScreen(
        key: ValueKey('setup-${session.familyId}'),
        existingFamilyId: session.familyId,
        existingName: session.household?.name,
      ),
      SessionStage.ready => const HomeShell(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: NotebookPaper(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📒', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text('Открываем тетрадь…', style: TextStyle(color: Pen.blue, fontSize: 18)),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

/// Показывается, если Firebase для платформы ещё не настроен.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.details});
  final String details;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildNotebookTheme(),
    home: Scaffold(
      body: NotebookPaper(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔧', style: TextStyle(fontSize: 56)),
                const PenTitle('Firebase ещё не настроен', color: Pen.red),
                const Text(
                  'Выполните `flutterfire configure --project=poleznie-privichki` '
                  'и пересоберите приложение (см. README).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pen.pencil, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
