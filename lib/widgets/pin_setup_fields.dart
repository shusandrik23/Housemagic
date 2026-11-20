import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Два поля: PIN и повтор PIN (4 цифры).
class PinSetupFields extends StatelessWidget {
  const PinSetupFields({super.key, required this.pin, required this.repeat});
  final TextEditingController pin;
  final TextEditingController repeat;

  /// Возвращает текст ошибки или `null`, если всё верно.
  static String? validate(String pin, String repeat) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) return 'PIN-код — ровно 4 цифры';
    if (pin != repeat) return 'PIN-коды не совпадают';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(labelText: label, counterText: '');
    final formatters = [FilteringTextInputFormatter.digitsOnly];
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: pin,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            decoration: deco('PIN (4 цифры)'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: repeat,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            decoration: deco('Повторите PIN'),
          ),
        ),
      ],
    );
  }
}
