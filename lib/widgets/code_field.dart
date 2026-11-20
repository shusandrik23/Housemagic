import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/codes.dart';
import '../core/theme.dart';

/// Поле ввода 6-символьного кода семьи (формат YouBoost: буквы и цифры).
class FamilyCodeField extends StatelessWidget {
  const FamilyCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
    this.fontSize = 30,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final double fontSize;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    maxLength: 6,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: TextCapitalization.characters,
    inputFormatters: const [_CodeFormatter()],
    style: TextStyle(fontSize: fontSize, letterSpacing: 10, color: Pen.blue),
    decoration: const InputDecoration(hintText: 'AB3K9Q', counterText: ''),
    onSubmitted: onSubmitted,
  );
}

class _CodeFormatter extends TextInputFormatter {
  const _CodeFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = Codes.normalize(newValue.text);
    final clipped = text.length > 6 ? text.substring(0, 6) : text;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}
