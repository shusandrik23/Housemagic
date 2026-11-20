import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/codes.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/code_field.dart';
import '../../widgets/notebook.dart';

/// Экран входа в стиле тетрадного листа.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _codeController = TextEditingController();
  bool _showCode = false;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? _validCodeOrNull() {
    final code = Codes.normalize(_codeController.text);
    return Codes.isValidFamilyCode(code) ? code : null;
  }

  Future<void> _google() async {
    if (_showCode && _codeController.text.isNotEmpty && _validCodeOrNull() == null) {
      showSnack(context, 'Код — это 6 букв и цифр', error: true);
      return;
    }
    await _run(() async {
      context.read<SessionController>().pendingCode = _showCode ? _validCodeOrNull() : null;
      await context.read<AppServices>().auth.signInWithGoogle();
    });
  }

  Future<void> _childDevice() async {
    final code = _validCodeOrNull();
    if (code == null) {
      showSnack(context, 'Введите код привязки от родителя (6 символов)', error: true);
      return;
    }
    await _run(() async {
      context.read<SessionController>().pendingCode = code;
      await context.read<AppServices>().auth.signInAnonymously();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, 'Не удалось войти: ${e.message ?? e.code}', error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Не удалось войти: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotebookPaper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('📒', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
                    const Text(
                      'Чистый Лист',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Pen.blue),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Каждый день — с чистого листа.\nУборка по 20 минут, питомец и пуговицы.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Pen.pencil, fontSize: 16),
                    ),
                    const SizedBox(height: 36),
                    FilledButton.icon(
                      key: const ValueKey('google-sign-in'),
                      onPressed: _busy ? null : _google,
                      icon: const Text(
                        'G',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      label: const Text('Войти через Google', style: TextStyle(fontSize: 17)),
                    ),
                    const SizedBox(height: 12),
                    if (!_showCode)
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _showCode = true),
                        child: const Text('Войти по коду приглашения в дом'),
                      ),
                    if (_showCode) ...[
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Код приглашения или привязки',
                                style: TextStyle(color: Pen.red, fontWeight: FontWeight.w700),
                              ),
                              FamilyCodeField(
                                key: const ValueKey('invite-code'),
                                controller: _codeController,
                                fontSize: 28,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Взрослым: войдите через Google — после входа вы попадёте в семью по этому коду. '
                                '(Подойдёт и код из YouBoost, если вы им пользуетесь.)',
                                style: TextStyle(color: Pen.pencil),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _childDevice,
                                icon: const Text('🧒'),
                                label: const Text('Это телефон ребёнка — войти без Google'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
