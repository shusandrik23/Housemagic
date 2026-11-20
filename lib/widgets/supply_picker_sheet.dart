import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/shopping_logic.dart';
import '../core/theme.dart';
import '../repositories/paths.dart';
import '../services/app_services.dart';
import '../state/session_controller.dart';
import 'notebook.dart';

/// Быстрый пикер «Закончилось средство / Нужны материалы».
/// Добавляет позицию строго во вкладку «Для дома и уборки».
class SupplyPickerSheet extends StatefulWidget {
  const SupplyPickerSheet({super.key, required this.repair});

  /// `true` — открыт из карточки «Ремонт по дому».
  final bool repair;

  static Future<void> show(BuildContext context, {required bool repair}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pen.paper,
      builder: (_) => SupplyPickerSheet(repair: repair),
    );
  }

  @override
  State<SupplyPickerSheet> createState() => _SupplyPickerSheetState();
}

class _SupplyPickerSheetState extends State<SupplyPickerSheet> {
  final _controller = TextEditingController();
  final _added = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String title, {String? category}) async {
    if (title.trim().isEmpty || _busy) return;
    final session = context.read<SessionController>();
    final services = context.read<AppServices>();
    final household = session.household;
    if (household == null) return;
    setState(() => _busy = true);
    try {
      final created = await services.shopping.addSupplyFromTask(
        householdId: household.id,
        title: title,
        category: category,
        addedByUid: session.uid ?? '',
        addedByName: session.activeProfile.displayName,
      );
      if (!mounted) return;
      setState(() => _added.add(title.trim()));
      showSnack(
        context,
        created ? '«${title.trim()}» → Для дома и уборки' : '«${title.trim()}» уже в списке',
      );
      _controller.clear();
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
    final modifiers = context.select<SessionController, List<String>>(
      (s) => s.household?.modifiers ?? const [],
    );
    final suggestions = SupplySuggestion.forContext(repair: widget.repair, modifiers: modifiers);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PenTitle(
            widget.repair ? '🔧 Нужны материалы' : '🧴 Закончилось средство',
            color: Pen.red,
          ),
          const Text(
            'Попадёт во вкладку «Для дома и уборки», не в продукты.',
            style: TextStyle(color: Pen.pencil),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: _added.contains(s.title)
                      ? const Icon(Icons.check, size: 18, color: Pen.green)
                      : null,
                  label: Text(s.title),
                  onPressed: () => _add(s.title, category: s.category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Своё название…'),
                  onSubmitted: (v) => _add(v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Pen.blue, size: 32),
                onPressed: () => _add(_controller.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }
}
