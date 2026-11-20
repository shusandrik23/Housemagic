import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/child_quest.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../../widgets/supply_picker_sheet.dart';
import '../family/approvals_screen.dart';
import 'daily_cards.dart';

/// Разворот «Сегодня»: стикер проверки квестов, 20-минутная зона,
/// карточка «Ремонт по дому».
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Stream<List<ChildQuest>>? _pending;
  String? _householdId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<SessionController>().household?.id;
    if (id != null && id != _householdId) {
      _householdId = id;
      _pending = context.read<AppServices>().quests.watchPendingApprovals(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final household = session.household!;
    final me = session.me;
    final rooms = household.rooms.isEmpty ? const ['Кухня'] : household.rooms;
    final zone = rooms[DateTime.now().weekday % rooms.length];
    return NotebookPaper(
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                Expanded(child: PenTitle('Сегодня, ${_today()}', size: 22)),
                ButtonsBadge(count: me?.coinsBalance ?? 0),
              ],
            ),
            StreamBuilder<List<ChildQuest>>(
              stream: _pending,
              builder: (context, snap) {
                final pending = snap.data ?? const [];
                if (pending.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Sticker(
                    key: const ValueKey('approval-sticker'),
                    onTap: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen())),
                    child: Row(
                      children: [
                        const Text('📌', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Проверить квест ребёнка (${pending.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
            DailyProgressScope(
              builder: (context, progress) => Column(
                children: [
                  MiniTaskCard(progress: progress),
                  DailyRulesCard(progress: progress),
                ],
              ),
            ),
            ZoneTimerCard(zone: zone),
            const SizedBox(height: 8),
            const RepairCard(),
          ],
        ),
      ),
    );
  }

  String _today() {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]}';
  }
}

/// Карточка активной уборки с 20-минутным таймером.
class ZoneTimerCard extends StatefulWidget {
  const ZoneTimerCard({super.key, required this.zone});
  final String zone;

  @override
  State<ZoneTimerCard> createState() => _ZoneTimerCardState();
}

class _ZoneTimerCardState extends State<ZoneTimerCard> {
  static const _total = Duration(minutes: 20);
  Duration _left = _total;
  Timer? _timer;

  bool get _running => _timer != null;

  void _toggle() {
    if (_running) {
      _timer!.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_left.inSeconds <= 1) {
          t.cancel();
          setState(() {
            _left = Duration.zero;
            _timer = null;
          });
          showSnack(context, 'Зона «${widget.zone}» убрана! 🎉');
        } else {
          setState(() => _left -= const Duration(seconds: 1));
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _left = _total;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = _left.inMinutes.toString().padLeft(2, '0');
    final ss = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Зона дня · 20 минут',
              style: TextStyle(color: Pen.red, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.zone,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Pen.blue),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$mm:$ss',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: Pen.blue,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: 1 - _left.inSeconds / _total.inSeconds,
              color: Pen.green,
              backgroundColor: Pen.grid,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Пауза' : 'Старт'),
                ),
                OutlinedButton(onPressed: _reset, child: const Text('Сброс')),
                OutlinedButton.icon(
                  key: const ValueKey('out-of-supplies'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Pen.red,
                    side: const BorderSide(color: Pen.red),
                  ),
                  onPressed: () => SupplyPickerSheet.show(context, repair: false),
                  icon: const Text('🧴'),
                  label: const Text('Закончилось средство'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка «Ремонт по дому».
class RepairCard extends StatelessWidget {
  const RepairCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 Ремонт по дому',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Pen.blue),
            ),
            const SizedBox(height: 4),
            const Text(
              'Перегорела лампочка, капает кран, отвалилась ручка? '
              'Запишите, что нужно купить, — список «Для дома и уборки» не потеряется.',
              style: TextStyle(color: Pen.pencil),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('need-materials'),
              onPressed: () => SupplyPickerSheet.show(context, repair: true),
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('Нужны материалы'),
            ),
          ],
        ),
      ),
    );
  }
}
