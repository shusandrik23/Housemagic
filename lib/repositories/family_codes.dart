import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/codes.dart';
import 'paths.dart';

/// Код подключения в формате YouBoost: `kidsCodes/{code}` →
/// `{ fid, role: 'parent'|'child', kidId, by, expires }`.
class FamilyCode {
  const FamilyCode({
    required this.code,
    required this.fid,
    required this.role,
    required this.kidId,
    required this.expires,
  });

  final String code;
  final String fid;
  final String role;
  final String? kidId;
  final DateTime expires;

  bool get isChild => role == FamilyRole.child;
}

class FamilyCodes {
  FamilyCodes(this.paths, {Random? random, DateTime Function()? clock})
    // ignore: prefer_initializing_formals
    : _random = random,
      _clock = clock ?? DateTime.now;

  final Paths paths;
  final Random? _random;
  final DateTime Function() _clock;

  /// Создаёт код на сутки (правила YouBoost: не дольше 25 часов).
  Future<FamilyCode> create({
    required String fid,
    required String role,
    String? kidId,
    required String byUid,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = Codes.familyCode(_random);
      final ref = paths.kidsCodes.doc(code);
      final existing = await ref.get();
      if (existing.exists) continue;
      final expires = _clock().add(Codes.lifetime);
      await ref.set({
        'fid': fid,
        'role': role,
        'kidId': kidId,
        'by': byUid,
        'expires': Timestamp.fromDate(expires),
      });
      return FamilyCode(code: code, fid: fid, role: role, kidId: kidId, expires: expires);
    }
    throw UserFacingException('Не удалось создать код, попробуйте ещё раз');
  }

  /// Проверяет код: существует и не просрочен.
  Future<FamilyCode> resolve(String raw) async {
    final code = Codes.normalize(raw);
    if (!Codes.isValidFamilyCode(code)) {
      throw UserFacingException('Код — это 6 букв и цифр');
    }
    final snap = await paths.kidsCodes.doc(code).get();
    if (!snap.exists) throw UserFacingException('Код не найден — проверьте символы');
    final d = snap.data()!;
    final expires = (d['expires'] as Timestamp?)?.toDate() ?? DateTime(2000);
    if (expires.isBefore(_clock())) {
      throw UserFacingException('Срок кода истёк — попросите новый');
    }
    return FamilyCode(
      code: code,
      fid: d['fid'] as String,
      role: d['role'] as String? ?? FamilyRole.parent,
      kidId: d['kidId'] as String?,
      expires: expires,
    );
  }
}
