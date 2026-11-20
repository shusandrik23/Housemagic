import '../core/daily.dart';
import 'firestore_utils.dart';

/// Дом = общая семья YouBoost (`kidsFamilies/{fid}`) + надстройка
/// Чистого Листа (`households/{fid}`) с тем же id.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.parentPinHash,
    required this.inviteCode,
    required this.inviteCodeExpires,
    required this.modifiers,
    required this.rooms,
    required this.isConfigured,
    this.usesYouBoost = false,
    this.dailyRules = DailyRule.defaults,
  });

  final String id;
  final String name;
  final String ownerUid;
  final String? parentPinHash;
  final String? inviteCode;
  final DateTime? inviteCodeExpires;
  final List<String> modifiers;
  final List<String> rooms;

  /// `false`, если семью создали в YouBoost и Чистый Лист ещё не настроен
  /// (нет документа `households/{fid}`).
  final bool isConfigured;

  /// Семьёй пользуются и в YouBoost. Только тогда интерфейс упоминает
  /// YouBoost. Тот, у кого установлен один Чистый Лист, этих подсказок не видит.
  final bool usesYouBoost;

  /// Ежедневные правила дома (по умолчанию — [DailyRule.defaults]).
  final List<DailyRule> dailyRules;

  bool get hasPin => (parentPinHash ?? '').isNotEmpty;

  bool get hasActiveInvite =>
      (inviteCode ?? '').isNotEmpty &&
      inviteCodeExpires != null &&
      inviteCodeExpires!.isAfter(DateTime.now());

  factory Household.fromParts({
    required String id,
    required Map<String, dynamic> family,
    Map<String, dynamic>? ext,
    bool kidsHaveHabits = false,
  }) {
    final e = ext ?? const <String, dynamic>{};
    final rewards = family['rewards'];
    final challenges = family['challenges'];
    final familyName = family['name'] as String? ?? '';
    final extName = e['name'] as String? ?? '';
    return Household(
      id: id,
      name: familyName.isNotEmpty ? familyName : (extName.isNotEmpty ? extName : 'Наш Дом'),
      ownerUid: family['owner'] as String? ?? '',
      parentPinHash: e['parentPinHash'] as String?,
      inviteCode: e['inviteCode'] as String?,
      inviteCodeExpires: readDate(e['inviteCodeExpires']),
      modifiers: readStringList(e['modifiers']),
      rooms: readStringList(e['rooms']),
      isConfigured: ext != null,
      dailyRules: e['dailyRules'] is List
          ? (e['dailyRules'] as List).map(DailyRule.fromMap).whereType<DailyRule>().toList()
          : DailyRule.defaults,
      // Признаки YouBoost: семья создана там, есть награды/вызовы YouBoost
      // или у детей заведены привычки.
      usesYouBoost:
          ext == null ||
          e['createdIn'] == 'youboost' ||
          (rewards is List && rewards.isNotEmpty) ||
          (challenges is List && challenges.isNotEmpty) ||
          kidsHaveHabits,
    );
  }
}

enum MemberRole {
  admin('admin'),
  member('member');

  const MemberRole(this.value);
  final String value;
}

/// Взрослый участник: запись `kidsFamilies/{fid}/members/{uid}` с
/// `role: 'parent'` + игровая статистика `households/{fid}/members/{uid}`.
class Member {
  const Member({
    required this.uid,
    required this.role,
    required this.name,
    required this.petType,
    required this.coinsBalance,
    required this.streakCount,
  });

  final String uid;

  /// `admin` — создатель семьи (owner), `member` — второй взрослый.
  final MemberRole role;
  final String name;
  final String petType;
  final int coinsBalance;
  final int streakCount;

  bool get isAdmin => role == MemberRole.admin;

  factory Member.fromParts({
    required String uid,
    required String ownerUid,
    required Map<String, dynamic> familyMember,
    Map<String, dynamic>? stats,
  }) {
    final s = stats ?? const <String, dynamic>{};
    final rawName = (s['name'] as String?)?.isNotEmpty == true
        ? s['name'] as String
        : familyMember['name'] as String? ?? '';
    return Member(
      uid: uid,
      role: uid == ownerUid ? MemberRole.admin : MemberRole.member,
      name: rawName.isEmpty ? 'Взрослый' : rawName.split(' ').first,
      petType: s['petType'] as String? ?? 'hedgehog',
      coinsBalance: readInt(s['coinsBalance']),
      streakCount: readInt(s['streakCount']),
    );
  }
}
