import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/age_group.dart';
import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../repositories/paths.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';
import '../../widgets/pin_setup_fields.dart';

/// Карточка-вкладыш «+ Добавить ребёнка» (локальный профиль).
class AddChildSheet extends StatefulWidget {
  const AddChildSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pen.paper,
    builder: (_) => const AddChildSheet(),
  );

  @override
  State<AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<AddChildSheet> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _pinRepeat = TextEditingController();
  AgeGroup _age = AgeGroup.middle;
  String _pet = 'dragon';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _pinRepeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<SessionController>();
    final services = context.read<AppServices>();
    final household = session.household!;
    final needsPin = !household.hasPin;
    if (needsPin) {
      final err = PinSetupFields.validate(_pin.text, _pinRepeat.text);
      if (err != null) {
        showSnack(context, err, error: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      if (needsPin) await services.households.changePin(household.id, _pin.text);
      await services.children.addChild(
        householdId: household.id,
        name: _name.text,
        ageGroup: _age,
        petType: _pet,
        createdByUid: session.uid!,
        order: session.childProfiles.length,
      );
      if (mounted) Navigator.of(context).pop();
    } on UserFacingException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Ошибка: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsPin = !(context.read<SessionController>().household?.hasPin ?? false);
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
            const PenTitle('🧒 Новый Юный Хранитель', size: 22),
            TextField(
              key: const ValueKey('child-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Имя ребёнка'),
            ),
            const PenTitle('Возраст', size: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final g in AgeGroup.values)
                  ChoiceChip(
                    label: Text('${g.label} · ${g.timerMinutes} мин'),
                    selected: _age == g,
                    onSelected: (_) => setState(() => _age = g),
                  ),
              ],
            ),
            const PenTitle('Питомец-напарник', size: 16),
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
            if (needsPin) ...[
              const PenTitle('Родительский PIN-код', color: Pen.red, size: 16),
              PinSetupFields(pin: _pin, repeat: _pinRepeat),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '🔒 Выход из детского режима защищён Родительским PIN-кодом дома.',
                  style: TextStyle(color: Pen.pencil),
                ),
              ),
            if (context.read<SessionController>().household?.usesYouBoost ?? false)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Ребёнок появится и в YouBoost — семья общая.',
                  style: TextStyle(color: Pen.green, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('save-child'),
                onPressed: _busy ? null : _save,
                child: const Text('Добавить ребёнка'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
