import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/age_group.dart';
import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/child_profile.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';

/// Родитель выдаёт ребёнку квест с монстриком.
class AddQuestSheet extends StatefulWidget {
  const AddQuestSheet({super.key, required this.child});
  final ChildProfile child;

  static Future<void> show(BuildContext context, {required ChildProfile child}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Pen.paper,
        builder: (_) => AddQuestSheet(child: child),
      );

  static int defaultReward(AgeGroup g) => switch (g) {
    AgeGroup.small => 5,
    AgeGroup.middle => 8,
    AgeGroup.teen => 12,
  };

  @override
  State<AddQuestSheet> createState() => _AddQuestSheetState();
}

class _AddQuestSheetState extends State<AddQuestSheet> {
  QuestTemplate _template = Catalog.questTemplates.first;
  late final _title = TextEditingController(text: _template.title);
  late int _reward = AddQuestSheet.defaultReward(widget.child.ageGroup);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().quests.createQuest(
        householdId: session.household!.id,
        childId: widget.child.id,
        title: _title.text.trim().isEmpty ? _template.title : _title.text.trim(),
        monster: _template.monster,
        emoji: _template.emoji,
        durationMinutes: widget.child.ageGroup.timerMinutes,
        rewardButtons: _reward,
        createdByUid: session.uid!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Ошибка: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PenTitle('Квест для ${widget.child.name}', size: 22),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in Catalog.questTemplates)
                ChoiceChip(
                  label: Text('${t.emoji} ${t.monster}'),
                  selected: _template == t,
                  onSelected: (_) => setState(() {
                    _template = t;
                    _title.text = t.title;
                  }),
                ),
            ],
          ),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Задание'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '⏱ ${widget.child.ageGroup.timerMinutes} мин · награда:',
                style: const TextStyle(color: Pen.pencil),
              ),
              IconButton(
                onPressed: _reward > 1 ? () => setState(() => _reward--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_reward 🟡', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => setState(() => _reward++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Выдать квест')),
          ),
        ],
      ),
    );
  }
}
