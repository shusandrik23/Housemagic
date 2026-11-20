import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../repositories/paths.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../../widgets/pin_setup_fields.dart';

/// Онбординг: создание нового Дома, либо настройка Чистого Листа для
/// семьи, уже созданной в YouBoost ([existingFamilyId]).
class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key, this.existingFamilyId, this.existingName});

  final String? existingFamilyId;
  final String? existingName;

  bool get isSetup => existingFamilyId != null;

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  late final _householdName = TextEditingController(
    text: (widget.existingName ?? '').isNotEmpty ? widget.existingName : 'Наш Дом',
  );
  late final _ownerName = TextEditingController(
    text: context.read<SessionController>().displayName,
  );
  final _pin = TextEditingController();
  final _pinRepeat = TextEditingController();
  final _rooms = <String>{'Кухня', 'Гостиная', 'Спальня', 'Ванная', 'Прихожая'};
  final _modifiers = <String>{};
  String _pet = 'hedgehog';
  bool _busy = false;

  @override
  void dispose() {
    _householdName.dispose();
    _ownerName.dispose();
    _pin.dispose();
    _pinRepeat.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final pinError = PinSetupFields.validate(_pin.text, _pinRepeat.text);
    if (pinError != null) {
      showSnack(context, pinError, error: true);
      return;
    }
    if (_rooms.isEmpty) {
      showSnack(context, 'Выберите хотя бы одну комнату', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final session = context.read<SessionController>();
      final repo = context.read<AppServices>().households;
      final ownerName = _ownerName.text.trim().isEmpty
          ? session.displayName
          : _ownerName.text.trim();
      final rooms = Catalog.rooms.where(_rooms.contains).toList();
      if (widget.isSetup) {
        await repo.configureHousehold(
          fid: widget.existingFamilyId!,
          uid: session.uid!,
          memberName: ownerName,
          householdName: _householdName.text,
          rooms: rooms,
          modifiers: _modifiers.toList(),
          petType: _pet,
          parentPin: _pin.text,
        );
      } else {
        await repo.createHousehold(
          ownerUid: session.uid!,
          ownerName: ownerName,
          householdName: _householdName.text,
          rooms: rooms,
          modifiers: _modifiers.toList(),
          petType: _pet,
          parentPin: _pin.text,
        );
      }
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).popUntil((r) => r.isFirst);
    } on UserFacingException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Не удалось создать дом: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSetup ? 'Настройка Дома' : 'Новый Дом'),
        actions: [
          if (widget.isSetup)
            TextButton(
              onPressed: () => context.read<SessionController>().signOut(),
              child: const Text('Выйти'),
            ),
        ],
      ),
      body: NotebookPaper(
        child: PageBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              if (widget.isSetup)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Ваша семья уже есть в YouBoost — состав семьи и дети подтянутся автоматически. '
                    'Осталось настроить уборку.',
                    style: TextStyle(color: Pen.green, fontWeight: FontWeight.w600),
                  ),
                ),
              const PenTitle('1. Как назовём Дом?'),
              TextField(controller: _householdName),
              TextField(
                controller: _ownerName,
                decoration: const InputDecoration(labelText: 'Ваше имя в семье'),
              ),
              const PenTitle('2. Какие комнаты убираем?'),
              Wrap(
                spacing: 8,
                children: [
                  for (final room in Catalog.rooms)
                    FilterChip(
                      label: Text(room),
                      selected: _rooms.contains(room),
                      onSelected: (v) => setState(() => v ? _rooms.add(room) : _rooms.remove(room)),
                    ),
                ],
              ),
              const PenTitle('3. Особенности дома'),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in Catalog.modifiers.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _modifiers.contains(e.key),
                      onSelected: (v) =>
                          setState(() => v ? _modifiers.add(e.key) : _modifiers.remove(e.key)),
                    ),
                ],
              ),
              const PenTitle('4. Питомец-компаньон'),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in Catalog.pets.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _pet == e.key,
                      onSelected: (_) => setState(() => _pet = e.key),
                    ),
                ],
              ),
              const PenTitle('5. Родительский PIN-код', color: Pen.red),
              const Text(
                'Нужен для выхода из детского режима — чтобы ребёнок не подтверждал свои квесты сам.',
                style: TextStyle(color: Pen.pencil),
              ),
              PinSetupFields(pin: _pin, repeat: _pinRepeat),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.isSetup ? 'Готово ✍️' : 'Создать Дом ✍️',
                        style: const TextStyle(fontSize: 17),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
