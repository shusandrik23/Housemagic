import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../onboarding/create_household_screen.dart';
import 'code_entry_screen.dart';

/// Первый вход: «Создать новый Дом» или «Присоединиться к существующему».
class HouseholdChoiceScreen extends StatefulWidget {
  const HouseholdChoiceScreen({super.key});

  @override
  State<HouseholdChoiceScreen> createState() => _HouseholdChoiceScreenState();
}

class _HouseholdChoiceScreenState extends State<HouseholdChoiceScreen> {
  @override
  void initState() {
    super.initState();
    // Если код был введён на экране входа — сразу обрабатываем его.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      final code = session.pendingCode;
      if (code != null) {
        session.pendingCode = null;
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => CodeEntryScreen(initialCode: code)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final name = session.displayName;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чистый Лист'),
        actions: [TextButton(onPressed: session.signOut, child: const Text('Выйти'))],
      ),
      body: NotebookPaper(
        child: PageBody(
          maxWidth: 520,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              PenTitle('Привет, $name! 👋', size: 26),
              const Text('С чего начнём?', style: TextStyle(fontSize: 17, color: Pen.pencil)),
              const SizedBox(height: 24),
              _ChoiceCard(
                emoji: '🏡',
                title: 'Создать новый Дом',
                subtitle: 'Комнаты, особенности дома, питомец-компаньон и Родительский PIN-код.',
                color: Pen.blue,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const CreateHouseholdScreen())),
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                emoji: '🔑',
                title: 'Присоединиться к Дому',
                subtitle: 'Введите 6-значный код приглашения (или код привязки детского телефона).',
                color: Pen.green,
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const CodeEntryScreen())),
              ),
              if (session.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(session.errorMessage!, style: const TextStyle(color: Pen.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Pen.pencil)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    ),
  );
}
