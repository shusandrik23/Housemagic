import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/child_profile.dart';
import '../../models/household.dart';
import '../../repositories/paths.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../../widgets/pin_dialog.dart';
import '../../widgets/pin_setup_fields.dart';
import 'add_child_sheet.dart';
import 'add_quest_sheet.dart';
import 'album_screen.dart';
import 'approvals_screen.dart';

/// Вкладка «Семья и Домик».
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final household = session.household!;
    return NotebookPaper(
      child: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _InviteCard(household: household),
            const PenTitle('Взрослые'),
            for (final m in session.members) _MemberTile(member: m, isMe: m.uid == session.uid),
            Row(
              children: [
                const Expanded(child: PenTitle('Дети · Академия Юных Хранителей')),
                if (session.isParent)
                  TextButton.icon(
                    key: const ValueKey('add-child'),
                    onPressed: () => AddChildSheet.show(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить ребёнка'),
                  ),
              ],
            ),
            if (session.childProfiles.isEmpty)
              Text(
                session.isParent
                    ? 'Добавьте ребёнка — у него будут свои квесты, питомец и золотые пуговицы.'
                    : 'Детей добавляют взрослые участники семьи.',
                style: const TextStyle(color: Pen.pencil),
              ),
            for (final c in session.childProfiles) ChildCard(child: c),
            const PenTitle('Семейное'),
            ListTile(
              leading: const Text('📌', style: TextStyle(fontSize: 22)),
              title: const Text('Проверить квесты детей'),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen())),
            ),
            ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 22)),
              title: const Text('Альбом Побед'),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const AlbumScreen())),
            ),
            if (session.isParent)
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Pen.red),
                title: const Text('Сменить Родительский PIN-код'),
                onTap: () => _changePin(context),
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: Pen.pencil),
              title: const Text('Выйти из аккаунта'),
              onTap: session.signOut,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final session = context.read<SessionController>();
    final services = context.read<AppServices>();
    final ok = await PinDialog.show(
      context,
      title: 'Текущий PIN-код',
      verify: (pin) async => session.verifyPin(pin),
    );
    if (!ok || !context.mounted) return;
    final pin = TextEditingController();
    final repeat = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый PIN-код'),
        content: PinSetupFields(pin: pin, repeat: repeat),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final err = PinSetupFields.validate(pin.text, repeat.text);
              if (err != null) {
                showSnack(ctx, err, error: true);
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await services.households.changePin(session.household!.id, pin.text);
      if (context.mounted) showSnack(context, 'PIN-код обновлён');
    }
  }
}

class _InviteCard extends StatefulWidget {
  const _InviteCard({required this.household});
  final Household household;

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _busy = false;

  Future<void> _create() async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().households.createParentInvite(
        fid: widget.household.id,
        byUid: session.uid!,
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Не удалось создать код: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.household;
    final isParent = context.select<SessionController, bool>((s) => s.isParent);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏡 ${h.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Pen.blue),
            ),
            const Text(
              'Семья общая с YouBoost: состав и дети синхронизируются.',
              style: TextStyle(color: Pen.green, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (h.hasActiveInvite) ...[
              const Text(
                'Код приглашения для второго взрослого (действует сутки):',
                style: TextStyle(color: Pen.pencil),
              ),
              Row(
                children: [
                  SelectableText(
                    h.inviteCode!,
                    style: const TextStyle(
                      fontSize: 30,
                      letterSpacing: 8,
                      color: Pen.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Скопировать',
                    icon: const Icon(Icons.copy, color: Pen.blue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: h.inviteCode!));
                      showSnack(context, 'Код скопирован');
                    },
                  ),
                ],
              ),
            ] else if (isParent)
              OutlinedButton.icon(
                key: const ValueKey('create-invite'),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Пригласить второго взрослого'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isMe});
  final Member member;
  final bool isMe;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Text(Catalog.petEmoji(member.petType), style: const TextStyle(fontSize: 28)),
    title: Text('${member.name}${isMe ? ' (вы)' : ''}'),
    subtitle: Text(member.isAdmin ? 'Администратор' : 'Участник'),
    trailing: ButtonsBadge(count: member.coinsBalance),
  );
}

/// Карточка-вкладыш ребёнка.
class ChildCard extends StatelessWidget {
  const ChildCard({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(Catalog.petEmoji(child.petType), style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Pen.blue,
                        ),
                      ),
                      Text(
                        '${child.ageGroup.label} · таймер ${child.ageGroup.timerMinutes} мин · '
                        '🔥 ${child.streakCount}',
                        style: const TextStyle(color: Pen.pencil),
                      ),
                      Text(
                        child.hasLinkedDevice
                            ? '📱 Свой телефон привязан'
                            : child.linkCode != null
                            ? '⏳ Ждёт привязки: код ${child.linkCode}'
                            : '🏠 Профиль на устройстве родителя',
                        style: const TextStyle(fontSize: 12, color: Pen.green),
                      ),
                    ],
                  ),
                ),
                ButtonsBadge(count: child.goldButtons, gold: true),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  key: ValueKey('enter-child-${child.id}'),
                  onPressed: () => session.enterChildMode(child.id),
                  icon: const Text('🛡'),
                  label: const Text('Детский режим'),
                ),
                OutlinedButton.icon(
                  onPressed: () => AddQuestSheet.show(context, child: child),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Квест'),
                ),
                if (session.isParent && !child.hasLinkedDevice)
                  OutlinedButton.icon(
                    onPressed: () => _link(context),
                    icon: const Icon(Icons.phonelink_setup),
                    label: const Text('Привязать телефон ребёнка'),
                  ),
                if (session.isParent && child.hasLinkedDevice)
                  TextButton(
                    onPressed: () => _unlink(context),
                    child: const Text('Отвязать телефон'),
                  ),
                TextButton(
                  onPressed: () => _editWishes(context),
                  child: const Text('🎁 Банк желаний'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _link(BuildContext context) async {
    final session = context.read<SessionController>();
    final services = context.read<AppServices>();
    try {
      final code = (await services.children.createLinkCode(
        householdId: session.household!.id,
        childId: child.id,
        createdByUid: session.uid!,
      )).code;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Телефон для ${child.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'На телефоне ребёнка откройте «Чистый Лист» (или YouBoost Kids) → '
                '«Войти по коду» и введите код. Он действует сутки:',
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 36,
                  letterSpacing: 10,
                  color: Pen.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Весь прогресс, пуговицы и питомец сохранятся.',
                style: TextStyle(color: Pen.pencil),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Готово'))],
        ),
      );
    } on UserFacingException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _unlink(BuildContext context) async {
    final session = context.read<SessionController>();
    await context.read<AppServices>().children.unlinkDevices(session.household!.id, child);
    if (context.mounted) showSnack(context, 'Телефон отвязан, прогресс сохранён');
  }

  Future<void> _editWishes(BuildContext context) async {
    final session = context.read<SessionController>();
    final services = context.read<AppServices>();
    final wishes = List<Wish>.from(child.wishes);
    final title = TextEditingController();
    final cost = TextEditingController(text: '50');
    final result = await showDialog<List<Wish>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Банк желаний · ${child.name}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final w in wishes)
                  ListTile(
                    dense: true,
                    title: Text(w.title),
                    subtitle: Text('${w.cost} 🟡'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => wishes.remove(w)),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: title,
                        decoration: const InputDecoration(hintText: 'Поход в кино'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cost,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(suffixText: '🟡'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final c = int.tryParse(cost.text) ?? 0;
                        if (title.text.trim().isEmpty || c <= 0) return;
                        setState(() => wishes.add(Wish(title: title.text.trim(), cost: c)));
                        title.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, wishes),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await services.children.updateWishes(session.household!.id, child.id, result);
    }
  }
}
