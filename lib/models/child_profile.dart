import '../core/age_group.dart';
import 'firestore_utils.dart';

/// Награда в «Банке желаний».
class Wish {
  const Wish({required this.title, required this.cost});
  final String title;
  final int cost;

  Map<String, dynamic> toMap() => {'title': title, 'cost': cost};

  factory Wish.fromMap(Map<String, dynamic> m) =>
      Wish(title: m['title'] as String? ?? '', cost: readInt(m['cost']));
}

/// Ребёнок = общая карточка YouBoost (`kidsFamilies/{fid}/kids/{kidId}`)
/// + надстройка Чистого Листа (`households/{fid}/children/{kidId}`).
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.ageGroup,
    required this.petType,
    required this.goldButtons,
    required this.streakCount,
    required this.linkedUids,
    required this.linkCode,
    required this.wishes,
  });

  final String id;
  final String name;
  final AgeGroup ageGroup;
  final String petType;
  final int goldButtons;
  final int streakCount;

  /// uid телефонов ребёнка (записи `members` с `role: 'child'`).
  final List<String> linkedUids;
  final String? linkCode;
  final List<Wish> wishes;

  bool get hasLinkedDevice => linkedUids.isNotEmpty;

  /// Профиль без собственного устройства — управляется с телефона родителя.
  bool get isManagedLocally => !hasLinkedDevice;
  String? get linkedUid => hasLinkedDevice ? linkedUids.first : null;

  factory ChildProfile.fromParts({
    required String id,
    required Map<String, dynamic> kid,
    Map<String, dynamic>? ext,
    List<String> linkedUids = const [],
  }) {
    final e = ext ?? const <String, dynamic>{};
    final rawWishes = e['wishes'];
    final age = kid['age'];
    return ChildProfile(
      id: id,
      name: kid['name'] as String? ?? e['name'] as String? ?? '',
      ageGroup: e['ageGroup'] is String
          ? AgeGroup.fromValue(e['ageGroup'] as String)
          : AgeGroup.fromAge(age is num ? age.toInt() : null),
      petType: e['petType'] as String? ?? 'dragon',
      goldButtons: readInt(e['goldButtons']),
      streakCount: readInt(e['streakCount']),
      linkedUids: linkedUids,
      linkCode: (readDate(e['linkCodeExpires'])?.isAfter(DateTime.now()) ?? false)
          ? e['linkCode'] as String?
          : null,
      wishes: rawWishes is List
          ? rawWishes
                .whereType<Map>()
                .map((m) => Wish.fromMap(Map<String, dynamic>.from(m)))
                .toList()
          : const [],
    );
  }
}
