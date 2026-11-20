import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/daily.dart';
import '../../core/streak.dart';
import '../../core/theme.dart';
import '../../models/daily_progress.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';

/// Подписка на отметки текущего взрослого за сегодня.
class DailyProgressScope extends StatefulWidget {
  const DailyProgressScope({super.key, required this.builder});
  final Widget Function(BuildContext context, DailyProgress progress) builder;

  @override
  State<DailyProgressScope> createState() => _DailyProgressScopeState();
}

class _DailyProgressScopeState extends State<DailyProgressScope> {
  Stream<DailyProgress>? _stream;
  String? _key;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final fid = session.household?.id;
    final uid = session.uid;
    if (fid == null || uid == null) return widget.builder(context, const DailyProgress());
    final day = Streak.dayKey(DateTime.now());
    final key = '$fid/$uid/$day';
    if (key != _key) {
      _key = key;
      _stream = context.read<AppServices>().daily.watchDay(fid, uid, day);
    }
    return StreamBuilder<DailyProgress>(
      stream: _stream,
      builder: (context, snap) => widget.builder(context, snap.data ?? const DailyProgress()),
    );
  }
}

/// Мини-задача дня.
class MiniTaskCard extends StatefulWidget {
  const MiniTaskCard({super.key, required this.progress});
  final DailyProgress progress;

  @override
  State<MiniTaskCard> createState() => _MiniTaskCardState();
}

class _MiniTaskCardState extends State<MiniTaskCard> {
  bool _busy = false;

  Future<void> _done(MiniTask task) async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      final reward = await context.read<AppServices>().daily.completeMiniTask(
        fid: session.household!.id,
        uid: session.uid!,
        taskId: task.id,
      );
      if (mounted && reward > 0) showSnack(context, 'Мини-задача сделана! +$reward пуговиц');
    } catch (e) {
      if (mounted) showSnack(context, 'Ошибка: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = context.select<SessionController, ({List<String> rooms, List<String> mods})>(
      (s) => (rooms: s.household?.rooms ?? const [], mods: s.household?.modifiers ?? const []),
    );
    final task = MiniTask.forDay(DateTime.now(), rooms: household.rooms, modifiers: household.mods);
    final done = widget.progress.miniDone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(task.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Мини-задача дня · ${task.minutes} мин',
                    style: const TextStyle(color: Pen.red, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: done ? Pen.pencil : Pen.blue,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: Pen.red,
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            done
                ? const Text('✅', style: TextStyle(fontSize: 28))
                : FilledButton(
                    key: const ValueKey('mini-task-done'),
                    style: FilledButton.styleFrom(backgroundColor: Pen.green),
                    onPressed: _busy ? null : () => _done(task),
                    child: Text('Сделано  +${DailyRewards.miniTask}'),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Ежедневные правила: утренний и вечерний чек-лист.
class DailyRulesCard extends StatelessWidget {
  const DailyRulesCard({super.key, required this.progress});
  final DailyProgress progress;

  Future<void> _toggle(BuildContext context, DailyRule rule, List<DailyRule> rules) async {
    final session = context.read<SessionController>();
    try {
      final reward = await context.read<AppServices>().daily.setRule(
        fid: session.household!.id,
        uid: session.uid!,
        ruleId: rule.id,
        done: !progress.rulesDone.contains(rule.id),
        allRuleIds: rules.map((r) => r.id).toList(),
      );
      if (context.mounted && reward > 0) {
        showSnack(context, 'Все правила дня выполнены! +$reward пуговиц, серия растёт 🔥');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, 'Ошибка: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.select<SessionController, List<DailyRule>>(
      (s) => s.household?.dailyRules ?? DailyRule.defaults,
    );
    final done = rules.where((r) => progress.rulesDone.contains(r.id)).length;
    final streak = context.select<SessionController, int>((s) => s.me?.streakCount ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: PenTitle('Ежедневные правила', size: 18)),
                Text(
                  '$done/${rules.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: done == rules.length && rules.isNotEmpty ? Pen.green : Pen.blue,
                  ),
                ),
                IconButton(
                  key: const ValueKey('edit-rules'),
                  tooltip: 'Изменить правила',
                  icon: const Icon(Icons.edit_note, color: Pen.pencil),
                  onPressed: () => RulesEditorSheet.show(context, rules),
                ),
              ],
            ),
            LinearProgressIndicator(
              value: rules.isEmpty ? 0 : done / rules.length,
              color: Pen.green,
              backgroundColor: Pen.grid,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            if (rules.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Правил пока нет — добавьте свои через ✎',
                  style: TextStyle(color: Pen.pencil),
                ),
              ),
            for (final period in RulePeriod.values)
              if (rules.any((r) => r.period == period)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(
                    '${period.emoji} ${period.label}',
                    style: const TextStyle(color: Pen.red, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final rule in rules.where((r) => r.period == period))
                  _RuleRow(
                    rule: rule,
                    done: progress.rulesDone.contains(rule.id),
                    onTap: () => _toggle(context, rule, rules),
                  ),
              ],
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                progress.allRulesRewarded
                    ? '🔥 День засчитан · серия $streak'
                    : 'Все правила за день — +${DailyRewards.allRules} пуговиц и +1 к серии (сейчас $streak)',
                style: const TextStyle(fontSize: 12, color: Pen.pencil),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.done, required this.onTap});
  final DailyRule rule;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('rule-${rule.id}'),
    onTap: onTap,
    child: Row(
      children: [
        Checkbox(value: done, activeColor: Pen.green, onChanged: (_) => onTap()),
        Expanded(
          child: Text(
            rule.title,
            style: TextStyle(
              fontSize: 16,
              color: done ? Pen.pencil : Pen.blue,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: Pen.red,
              decorationThickness: 2,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Редактор ежедневных правил дома.
class RulesEditorSheet extends StatefulWidget {
  const RulesEditorSheet({super.key, required this.initial});
  final List<DailyRule> initial;

  static Future<void> show(BuildContext context, List<DailyRule> rules) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Pen.paper,
        builder: (_) => RulesEditorSheet(initial: rules),
      );

  @override
  State<RulesEditorSheet> createState() => _RulesEditorSheetState();
}

class _RulesEditorSheetState extends State<RulesEditorSheet> {
  late final List<DailyRule> _rules = [...widget.initial];
  final _title = TextEditingController();
  RulePeriod _period = RulePeriod.morning;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _rules.add(
        DailyRule(id: 'r${DateTime.now().microsecondsSinceEpoch}', title: t, period: _period),
      );
      _title.clear();
    });
  }

  Future<void> _save() async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().daily.saveRules(session.household!.id, _rules);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Ошибка: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = context.read<SessionController>().isParent;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PenTitle('Правила дома', size: 22),
            const Text(
              'Одинаковые для всех взрослых, отметки у каждого свои.',
              style: TextStyle(color: Pen.pencil),
            ),
            for (final r in _rules)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(r.period.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(r.title),
                trailing: isParent
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _rules.remove(r)),
                      )
                    : null,
              ),
            if (isParent) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Новое правило…'),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Pen.blue, size: 30),
                    onPressed: _add,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in RulePeriod.values)
                    ChoiceChip(
                      label: Text('${p.emoji} ${p.label}'),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _rules
                        ..clear()
                        ..addAll(DailyRule.defaults);
                    }),
                    child: const Text('Вернуть стандартные'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
