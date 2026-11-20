import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/child_quest.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';

/// Проверка детских квестов родителем: «Принять ✨» / «Переделать».
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late final Stream<List<ChildQuest>> _stream = context
      .read<AppServices>()
      .quests
      .watchPendingApprovals(context.read<SessionController>().household!.id);
  final _busy = <String>{};

  Future<void> _approve(ChildQuest q) async {
    final session = context.read<SessionController>();
    setState(() => _busy.add(q.id));
    try {
      await context.read<AppServices>().quests.approve(
        householdId: session.household!.id,
        questId: q.id,
        approverUid: session.uid!,
      );
      if (mounted) showSnack(context, 'Принято! +${q.rewardButtons} золотых пуговиц ✨');
    } catch (e) {
      if (mounted) showSnack(context, 'Ошибка: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(q.id));
    }
  }

  Future<void> _sendBack(ChildQuest q) async {
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Что подправить?'),
        content: TextField(
          controller: comment,
          decoration: const InputDecoration(hintText: 'Под кроватью ещё прячется носок 🧦'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Вернуть')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppServices>().quests.sendBack(
      householdId: context.read<SessionController>().household!.id,
      questId: q.id,
      comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kids = {for (final c in context.watch<SessionController>().childProfiles) c.id: c};
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка квестов')),
      body: NotebookPaper(
        child: PageBody(
          child: StreamBuilder<List<ChildQuest>>(
            stream: _stream,
            builder: (context, snap) {
              final quests = snap.data ?? const [];
              if (quests.isEmpty) {
                return const Center(
                  child: Text(
                    'Все квесты проверены 👌',
                    style: TextStyle(color: Pen.pencil, fontSize: 16),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final q in quests)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Catalog.petEmoji(kids[q.childId]?.petType)} '
                              '${kids[q.childId]?.name ?? 'Ребёнок'} победил(а) '
                              '${q.emoji} ${q.monster}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Pen.blue,
                                fontSize: 16,
                              ),
                            ),
                            Text(q.title, style: const TextStyle(color: Pen.pencil)),
                            const SizedBox(height: 8),
                            if (q.photoUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  q.photoUrl!,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    height: 80,
                                    child: Center(child: Text('📷 Фото недоступно')),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  key: ValueKey('approve-${q.id}'),
                                  style: FilledButton.styleFrom(backgroundColor: Pen.green),
                                  onPressed: _busy.contains(q.id) ? null : () => _approve(q),
                                  child: Text('Принять ✨  +${q.rewardButtons} 🟡'),
                                ),
                                TextButton(
                                  onPressed: _busy.contains(q.id) ? null : () => _sendBack(q),
                                  child: const Text('Переделать'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
