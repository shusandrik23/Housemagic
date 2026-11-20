import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/shopping_logic.dart';
import '../../core/theme.dart';
import '../../models/shopping_item.dart';
import '../../repositories/paths.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';

/// Две вкладки-закладки: «Продукты» и «Для дома и уборки».
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: NotebookPaper(
        child: Column(
          children: [
            const Material(
              color: Pen.paper,
              child: TabBar(
                labelColor: Pen.blue,
                unselectedLabelColor: Pen.pencil,
                indicatorColor: Pen.red,
                indicatorWeight: 3,
                tabs: [
                  Tab(key: ValueKey('tab-grocery'), text: '🥕 Продукты'),
                  Tab(key: ValueKey('tab-supplies'), text: '🧽 Для дома и уборки'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ShoppingListView(type: ShoppingListType.grocery),
                  ShoppingListView(type: ShoppingListType.householdSupplies),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key, required this.type});
  final ShoppingListType type;

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Stream<List<ShoppingItem>>? _stream;
  String? _householdId;
  String? _category; // null = авто
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<SessionController>().household?.id;
    if (id != null && id != _householdId) {
      _householdId = id;
      _stream = context.read<AppServices>().shopping.watchList(id, widget.type);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isGrocery => widget.type == ShoppingListType.grocery;

  Future<void> _add() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    final session = context.read<SessionController>();
    final entry = _isGrocery ? ShoppingLogic.parseQuickEntry(raw) : QuickEntry(raw, null);
    _input.clear();
    _focus.requestFocus();
    try {
      await context.read<AppServices>().shopping.addItem(
        householdId: _householdId!,
        listType: widget.type,
        title: entry.title,
        quantity: entry.quantity,
        category: _category,
        addedByUid: session.uid ?? '',
        addedByName: session.activeProfile.displayName,
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Не удалось добавить: $e', error: true);
    }
  }

  Future<void> _toggle(ShoppingItem item) async {
    final session = context.read<SessionController>();
    await context.read<AppServices>().shopping.setBought(
      householdId: _householdId!,
      itemId: item.id,
      isBought: !item.isBought,
      byUid: session.uid ?? '',
    );
  }

  Future<void> _completeTrip() async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      final reward = await context.read<AppServices>().shopping.completeTrip(
        householdId: _householdId!,
        listType: widget.type,
        byUid: session.uid ?? '',
        profile: session.activeProfile,
      );
      if (mounted) showSnack(context, 'Поход в магазин завершён! +$reward пуговиц 🎉');
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
    super.build(context);
    return StreamBuilder<List<ShoppingItem>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Ошибка: ${snap.error}', style: const TextStyle(color: Pen.red)),
          );
        }
        final items = snap.data ?? const <ShoppingItem>[];
        final boughtCount = items.where((i) => i.isBought).length;
        final grouped = <String, List<ShoppingItem>>{};
        for (final c in widget.type.categories) {
          final inCat = items.where((i) => i.category == c).toList()
            ..sort((a, b) => (a.isBought ? 1 : 0).compareTo(b.isBought ? 1 : 0));
          if (inCat.isNotEmpty) grouped[c] = inCat;
        }
        final uncategorized = items
            .where((i) => !widget.type.categories.contains(i.category))
            .toList();
        if (uncategorized.isNotEmpty) {
          grouped.putIfAbsent(widget.type.categories.last, () => []).addAll(uncategorized);
        }
        return PageBody(
          child: Column(
            children: [
              _QuickAddRow(
                controller: _input,
                focusNode: _focus,
                hint: _isGrocery ? 'Запишите строчку… «Молоко 2 л»' : 'Что закончилось? «Губки»',
                categories: widget.type.categories,
                category: _category,
                onCategory: (c) => setState(() => _category = c),
                onSubmit: _add,
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          snap.connectionState == ConnectionState.waiting
                              ? 'Листаем тетрадь…'
                              : 'Пока пусто — чистый лист ✨',
                          style: const TextStyle(color: Pen.pencil, fontSize: 16),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        children: [
                          for (final entry in grouped.entries) ...[
                            PenTitle(entry.key, color: Pen.red, size: 16),
                            for (final item in entry.value)
                              _ItemRow(
                                key: ValueKey(item.id),
                                item: item,
                                onToggle: () => _toggle(item),
                                onDelete: () => context.read<AppServices>().shopping.deleteItem(
                                  _householdId!,
                                  item.id,
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: ValueKey('complete-trip-${widget.type.value}'),
                      style: FilledButton.styleFrom(backgroundColor: Pen.green),
                      onPressed: boughtCount == 0 || _busy ? null : _completeTrip,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        boughtCount == 0
                            ? 'Завершить поход в магазин'
                            : 'Завершить поход в магазин · $boughtCount '
                                  '(+${ShoppingLogic.tripReward(boughtCount)} 🔘)',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final List<String> categories;
  final String? category;
  final ValueChanged<String?> onCategory;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          const Text('✎ ', style: TextStyle(color: Pen.blue, fontSize: 22)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Pen.blue, fontSize: 18),
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Отдел',
            icon: Icon(Icons.label_outline, color: category == null ? Pen.pencil : Pen.red),
            onSelected: (v) => onCategory(v == '__auto' ? null : v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: '__auto',
                checked: category == null,
                child: const Text('Авто'),
              ),
              for (final c in categories)
                CheckedPopupMenuItem(value: c, checked: category == c, child: Text(c)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Pen.blue, size: 30),
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({super.key, required this.item, required this.onToggle, required this.onDelete});
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 17,
      color: item.isBought ? Pen.pencil : Pen.blue,
      decoration: item.isBought ? TextDecoration.lineThrough : null,
      decorationColor: Pen.red,
      decorationThickness: 2,
    );
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Pen.red),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(value: item.isBought, activeColor: Pen.green, onChanged: (_) => onToggle()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: item.title, style: style),
                          if (item.quantity != null)
                            TextSpan(
                              text: '  ${item.quantity}',
                              style: style.copyWith(color: Pen.green, fontSize: 15),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      [
                        if (item.isAutoSuggested) '🧽 из уборки/ремонта',
                        if (item.addedByName.isNotEmpty) 'записал(а) ${item.addedByName}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: Pen.pencil),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
