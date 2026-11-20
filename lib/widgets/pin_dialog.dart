import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Ввод 4-значного Родительского PIN-кода.
///
/// [verify] возвращает `true`, если PIN верный; диалог закрывается с `true`.
/// [onBiometrics] — необязательная кнопка входа по биометрии.
class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    required this.verify,
    this.title = 'Родительский PIN-код',
    this.onBiometrics,
  });

  final Future<bool> Function(String pin) verify;
  final String title;
  final Future<bool> Function()? onBiometrics;

  static Future<bool> show(
    BuildContext context, {
    required Future<bool> Function(String pin) verify,
    String title = 'Родительский PIN-код',
    Future<bool> Function()? onBiometrics,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PinDialog(verify: verify, title: title, onBiometrics: onBiometrics),
    );
    return ok ?? false;
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  int _attempts = 0;

  Future<void> _press(String digit) async {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      setState(() => _busy = true);
      final ok = await widget.verify(_pin);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _attempts++;
        setState(() {
          _busy = false;
          _pin = '';
          _error = _attempts >= 3 ? 'Неверный PIN. Позовите взрослого 🙂' : 'Неверный PIN-код';
        });
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pen.paper,
      title: Text(widget.title, textAlign: TextAlign.center),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  key: ValueKey('pin-dot-$i'),
                  margin: const EdgeInsets.all(8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Pen.blue : Colors.transparent,
                    border: Border.all(color: Pen.blue, width: 2),
                  ),
                );
              }),
            ),
            SizedBox(
              height: 22,
              child: _error == null ? null : Text(_error!, style: const TextStyle(color: Pen.red)),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                  _Key(label: d, onTap: () => _press(d)),
                widget.onBiometrics == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Биометрия',
                        icon: const Icon(Icons.fingerprint, color: Pen.blue, size: 30),
                        onPressed: () async {
                          final ok = await widget.onBiometrics!();
                          if (ok && context.mounted) Navigator.of(context).pop(true);
                        },
                      ),
                _Key(label: '0', onTap: () => _press('0')),
                IconButton(
                  tooltip: 'Стереть',
                  icon: const Icon(Icons.backspace_outlined, color: Pen.blue),
                  onPressed: _backspace,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: OutlinedButton(
      key: ValueKey('pin-key-$label'),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
    ),
  );
}
