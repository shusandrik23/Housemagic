import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../repositories/family_codes.dart';
import '../../repositories/paths.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/code_field.dart';
import '../../widgets/notebook.dart';

/// Ввод кода семьи (из Чистого Листа или YouBoost).
/// Код взрослого → присоединение второго взрослого,
/// код ребёнка → устройство становится телефоном ребёнка.
class CodeEntryScreen extends StatefulWidget {
  const CodeEntryScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends State<CodeEntryScreen> {
  late final TextEditingController _code = TextEditingController(text: widget.initialCode ?? '');
  late final TextEditingController _name = TextEditingController(
    text: context.read<SessionController>().displayName,
  );
  String _pet = 'cat';
  bool _busy = false;
  FamilyCode? _parentCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _isAnonymous => context.read<SessionController>().firebaseUser?.isAnonymous ?? false;

  Future<void> _check() async {
    await _guard(() async {
      final services = context.read<AppServices>();
      final code = await services.households.resolveCode(_code.text);
      if (code.isChild) {
        await _linkChild(code.code);
      } else if (_isAnonymous) {
        throw UserFacingException('Это код для взрослого — войдите через Google на экране входа');
      } else {
        setState(() => _parentCode = code);
      }
    });
  }

  Future<void> _linkChild(String code) async {
    final services = context.read<AppServices>();
    final session = context.read<SessionController>();
    await services.children.linkDevice(deviceUid: session.uid!, code: code);
    if (!mounted) return;
    showSnack(context, 'Телефон привязан! Добро пожаловать в Академию 🛡');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _join() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Как вас зовут?', error: true);
      return;
    }
    await _guard(() async {
      final services = context.read<AppServices>();
      final session = context.read<SessionController>();
      await services.households.joinAsParent(
        uid: session.uid!,
        name: _name.text.trim(),
        petType: _pet,
        code: _parentCode!.code,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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
    final joining = _parentCode != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Код семьи')),
      body: NotebookPaper(
        child: PageBody(
          maxWidth: 520,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const PenTitle('Введите код (6 символов)'),
              const Text(
                'Код приглашения взрослого или код телефона ребёнка. Подойдёт и код из YouBoost.',
                style: TextStyle(color: Pen.pencil),
              ),
              FamilyCodeField(
                controller: _code,
                enabled: !joining,
                fontSize: 32,
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 16),
              if (!joining)
                FilledButton(onPressed: _busy ? null : _check, child: const Text('Проверить код')),
              if (joining) ...[
                const PenTitle('Семья найдена! Пара слов о вас', color: Pen.green),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Ваше имя в семье'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ваш питомец-компаньон',
                  style: TextStyle(color: Pen.blue, fontWeight: FontWeight.w600),
                ),
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: const Text('Присоединиться к семье'),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
