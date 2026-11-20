import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/child_profile.dart';
import '../../models/child_quest.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../../widgets/pin_dialog.dart';

/// Детский режим «Академия Юных Хранителей»: крупные кнопки, монстрики,
/// фото-отчёт родителям. Выход — только по Родительскому PIN-коду.
class ChildModeScreen extends StatefulWidget {
  const ChildModeScreen({super.key, required this.child});
  final ChildProfile child;

  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen> {
  late final Stream<List<ChildQuest>> _quests = context.read<AppServices>().quests.watchChildQuests(
    context.read<SessionController>().household!.id,
    widget.child.id,
  );
  final _uploading = <String>{};

  Future<bool> _askParent() async {
    final session = context.read<SessionController>();
    final biometrics = context.read<AppServices>().biometrics;
    final canBio = await biometrics.isAvailable();
    if (!mounted) return false;
    return PinDialog.show(
      context,
      title: 'Позови взрослого 🔒',
      verify: (pin) async => session.verifyPin(pin),
      onBiometrics: canBio ? biometrics.authenticate : null,
    );
  }

  Future<void> _exit() async {
    final session = context.read<SessionController>();
    if (!await _askParent()) return;
    if (session.isChildDevice) {
      await session.signOut();
    } else {
      await session.exitChildModeAfterBiometrics();
    }
  }

  Future<void> _startTimer(ChildQuest q) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestTimerDialog(quest: q),
    );
  }

  Future<void> _sendPhoto(ChildQuest q) async {
    final services = context.read<AppServices>();
    final householdId = context.read<SessionController>().household!.id;
    setState(() => _uploading.add(q.id));
    try {
      final url = await services.photos.captureAndUpload(
        householdId: householdId,
        questId: q.id,
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      );
      if (url == null) return;
      await services.quests.submitForApproval(
        householdId: householdId,
        questId: q.id,
        photoUrl: url,
      );
      if (mounted) showSnack(context, 'Фото-отчёт отправлен родителям! 📨');
    } catch (e) {
      if (mounted) showSnack(context, 'Не получилось отправить фото: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(q.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3C4),
        automaticallyImplyLeading: false,
        title: const Text('Академия Юных Хранителей'),
        actions: [
          IconButton(
            key: const ValueKey('exit-child-mode'),
            tooltip: 'Выйти (нужен взрослый)',
            icon: const Icon(Icons.lock_outline),
            onPressed: _exit,
          ),
        ],
      ),
      body: NotebookPaper(
        cell: 28,
        showMargin: false,
        child: PageBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Row(
                children: [
                  Text(Catalog.petEmoji(child.petType), style: const TextStyle(fontSize: 64)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Привет, ${child.name}!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Pen.blue,
                          ),
                        ),
                        Text(
                          '${child.ageGroup.rank} · 🔥 серия ${child.streakCount}',
                          style: const TextStyle(fontSize: 16, color: Pen.pencil),
                        ),
                      ],
                    ),
                  ),
                  ButtonsBadge(count: child.goldButtons, gold: true),
                ],
              ),
              const PenTitle('Монстрики на сегодня', color: Pen.red, size: 22),
              StreamBuilder<List<ChildQuest>>(
                stream: _quests,
                builder: (context, snap) {
                  final quests = snap.data ?? const [];
                  if (quests.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Все монстрики побеждены! Попроси у родителей новый квест 🎉',
                        style: TextStyle(fontSize: 18, color: Pen.green),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final q in quests)
                        _QuestCard(
                          quest: q,
                          uploading: _uploading.contains(q.id),
                          onTimer: () => _startTimer(q),
                          onPhoto: () => _sendPhoto(q),
                        ),
                    ],
                  );
                },
              ),
              if (child.wishes.isNotEmpty) ...[
                const PenTitle('🎁 Банк желаний', size: 22),
                for (final w in child.wishes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w.title} · ${w.cost} 🟡',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: w.cost == 0 ? 1 : (child.goldButtons / w.cost).clamp(0, 1),
                            minHeight: 10,
                            color: Pen.gold,
                            backgroundColor: Pen.grid,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          if (child.goldButtons >= w.cost)
                            const Text(
                              'Хватает! Покажи родителям ✨',
                              style: TextStyle(color: Pen.green),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.uploading,
    required this.onTimer,
    required this.onPhoto,
  });

  final ChildQuest quest;
  final bool uploading;
  final VoidCallback onTimer;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final pending = quest.status == QuestStatus.pendingApproval;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(quest.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.monster,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Pen.red,
                        ),
                      ),
                      Text(quest.title, style: const TextStyle(fontSize: 17)),
                      Text(
                        '⏱ ${quest.durationMinutes} мин · награда ${quest.rewardButtons} 🟡',
                        style: const TextStyle(color: Pen.pencil),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (quest.parentComment != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Sticker(child: Text('Родители: ${quest.parentComment}')),
              ),
            const SizedBox(height: 12),
            if (pending)
              const Text(
                '⏳ Ждём, когда родители проверят',
                style: TextStyle(fontSize: 17, color: Pen.green, fontWeight: FontWeight.w600),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: onTimer,
                      icon: const Icon(Icons.timer_outlined, size: 28),
                      label: const Text('Начать!', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      key: ValueKey('send-photo-${quest.id}'),
                      style: FilledButton.styleFrom(backgroundColor: Pen.green),
                      onPressed: uploading ? null : onPhoto,
                      icon: uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.photo_camera, size: 28),
                      label: const Text(
                        'Отправить фото-отчёт родителям',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestTimerDialog extends StatefulWidget {
  const _QuestTimerDialog({required this.quest});
  final ChildQuest quest;

  @override
  State<_QuestTimerDialog> createState() => _QuestTimerDialogState();
}

class _QuestTimerDialogState extends State<_QuestTimerDialog> {
  late int _left = widget.quest.durationMinutes * 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left == 0;
    final mm = (_left ~/ 60).toString().padLeft(2, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBEA),
      title: Text('${widget.quest.emoji} ${widget.quest.monster}', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            done ? 'Время вышло! Ты победил(а)? 🎉' : widget.quest.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            '$mm:$ss',
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: Pen.blue),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(done ? 'Сфотографировать' : 'Я справился(ась)!'),
        ),
      ],
    );
  }
}
