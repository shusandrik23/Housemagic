import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/age_group.dart';
import '../core/catalog.dart';
import '../models/child_profile.dart';
import 'family_codes.dart';
import 'household_repository.dart';
import 'paths.dart';

class ChildrenRepository {
  ChildrenRepository(FirebaseFirestore db, {FamilyCodes? codes})
    : paths = Paths(db),
      codes = codes ?? FamilyCodes(Paths(db));

  final Paths paths;
  final FamilyCodes codes;

  /// Сценарий 1: ребёнок, добавленный с аккаунта родителя. Создаётся общая
  /// карточка YouBoost (ребёнок появится и там) + надстройка Чистого Листа.
  Future<String> addChild({
    required String householdId,
    required String name,
    required AgeGroup ageGroup,
    required String petType,
    required String createdByUid,
    int order = 0,
    List<Wish> wishes = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw UserFacingException('Введите имя ребёнка');
    final kidRef = paths.familyKids(householdId).doc();
    final batch = paths.db.batch();
    // Те же поля, что создаёт YouBoost (js/family.js addKid).
    batch.set(kidRef, {
      'name': cleanName,
      'age': ageGroup.typicalAge,
      'avatar': YouBoostKid.avatars[order % YouBoostKid.avatars.length],
      'color': YouBoostKid.colors[order % YouBoostKid.colors.length],
      'habits': <Object>[],
      'marks': <String, Object>{},
      'approved': <String, Object>{},
      'requests': <Object>[],
      'decisions': <String, Object>{},
      'bonus': <Object>[],
      'chMarks': <String, Object>{},
      'pet': null,
      'order': order,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    batch.set(paths.children(householdId).doc(kidRef.id), {
      'name': cleanName,
      'ageGroup': ageGroup.value,
      'petType': petType,
      'goldButtons': 0,
      'streakCount': 0,
      'lastQuestDay': null,
      'isManagedLocally': true,
      'linkedUid': null,
      'linkCode': null,
      'wishes': wishes.map((w) => w.toMap()).toList(),
      'createdBy': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return kidRef.id;
  }

  /// Общие карточки детей: kidId → данные.
  Stream<Map<String, DocMap>> watchKids(String fid) =>
      paths.familyKids(fid).snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  /// Надстройки Чистого Листа: kidId → данные.
  Stream<Map<String, DocMap>> watchChildExt(String fid) =>
      paths.children(fid).snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  Future<void> updateWishes(String fid, String childId, List<Wish> wishes) => paths
      .children(fid)
      .doc(childId)
      .set({'wishes': wishes.map((w) => w.toMap()).toList()}, SetOptions(merge: true));

  /// Сценарий 2: «Привязать телефон ребёнка» — код на сутки в формате
  /// YouBoost (подходит и для YouBoost Kids).
  Future<FamilyCode> createLinkCode({
    required String householdId,
    required String childId,
    required String createdByUid,
  }) async {
    final c = await codes.create(
      fid: householdId,
      role: FamilyRole.child,
      kidId: childId,
      byUid: createdByUid,
    );
    await paths.children(householdId).doc(childId).set({
      'linkCode': c.code,
      'linkCodeExpires': Timestamp.fromDate(c.expires),
    }, SetOptions(merge: true));
    return c;
  }

  /// На устройстве ребёнка: код привязывает uid устройства к существующему
  /// ребёнку — пуговицы, серия и питомец сохраняются.
  Future<({String householdId, String childId})> linkDevice({
    required String deviceUid,
    required String code,
    String deviceName = 'Чистый Лист',
  }) async {
    final c = await codes.resolve(code);
    if (!c.isChild || c.kidId == null) {
      throw UserFacingException('Это код для взрослого. Ребёнку нужен код «Привязать телефон»');
    }
    await paths.familyMembers(c.fid).doc(deviceUid).set({
      'role': FamilyRole.child,
      'kidId': c.kidId,
      'code': c.code,
      'name': deviceName,
    });
    await paths.kidsUsers.doc(deviceUid).set({'fid': c.fid});
    return (householdId: c.fid, childId: c.kidId!);
  }

  /// Отвязать телефоны ребёнка (прогресс остаётся в профиле).
  Future<void> unlinkDevices(String fid, ChildProfile child) async {
    final batch = paths.db.batch();
    for (final uid in child.linkedUids) {
      batch.delete(paths.familyMembers(fid).doc(uid));
    }
    await batch.commit();
  }
}
