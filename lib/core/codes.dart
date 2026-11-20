import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Коды подключения к семье и хеширование Родительского PIN-кода.
///
/// Формат кодов совпадает с YouBoost (`kidsCodes/{code}`): 6 символов из
/// алфавита без похожих букв/цифр, поэтому код из одного приложения
/// работает в другом.
class Codes {
  Codes._();

  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const lifetime = Duration(hours: 24);
  static final Random _random = Random.secure();

  static String familyCode([Random? random]) {
    final r = random ?? _random;
    return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  /// «ab3-k9q» → «AB3K9Q».
  static String normalize(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidFamilyCode(String code) => RegExp(r'^[A-Z0-9]{6}$').hasMatch(code);

  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  /// SHA-256 хеш PIN-кода. Соль — id дома, чтобы одинаковые PIN в разных
  /// домах давали разные хеши.
  static String hashPin(String pin, {required String salt}) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool verifyPin(String pin, {required String salt, required String? hash}) {
    if (hash == null || hash.isEmpty) return false;
    return hashPin(pin, salt: salt) == hash;
  }
}
