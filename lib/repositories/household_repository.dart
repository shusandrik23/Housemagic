import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/codes.dart';
import '../models/household.dart';
import 'family_codes.dart';
import 'paths.dart';

typedef DocMap = Map<String, dynamic>;

class HouseholdRepository {
  HouseholdRepository(FirebaseFirestore db, {FamilyCodes? codes})
    : paths = Paths(db),
      codes = codes ?? FamilyCodes(Paths(db));

  final Paths paths;
  final FamilyCodes codes;

  /// Создаёт новый Дом: общую семью в формате YouBoost (её сразу увидит
  /// YouBoost) и надстройку Чистого Листа с тем же id.
  Future<String> createHousehold({
    required String ownerUid,
    required String ownerName,
    required String householdName,
    required List<String> rooms,
    required List<String> modifiers,
    required String petType,
    required String parentPin,
  }) async {
    if (!Codes.isValidPin(parentPin)) {
      throw UserFacingException('PIN-код должен состоять из 4 цифр');
    }
    final fid = paths.kidsFamilies.doc().id;
    final name = householdName.trim().isEmpty ? 'Наш Дом' : householdName.trim();
    final firstName = ownerName.trim().split(' ').first;
    // 1) Общая семья — те же поля, что пишет YouBoost (js/family.js createFamily).
    final batch = paths.db.batch();
    batch.set(paths.family(fid), {
      'name': name,
      'owner': ownerUid,
      'parents': {ownerUid: firstName},
      'challenges': <Object>[],
      'rewards': <Object>[],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    batch.set(paths.familyMembers(fid).doc(ownerUid), {
      'role': FamilyRole.parent,
      'name': ownerName.trim(),
    });
    batch.set(paths.kidsUsers.doc(ownerUid), {'fid': fid});
    await batch.commit();
    // 2) Надстройка Чистого Листа (правила требуют, чтобы пользователь уже
    //    был родителем семьи, поэтому — отдельной записью после первой).
    await configureHousehold(
      fid: fid,
      uid: ownerUid,
      memberName: ownerName,
      rooms: rooms,
      modifiers: modifiers,
      petType: petType,
      parentPin: parentPin,
    );
    return fid;
  }

  /// Настройка Чистого Листа для семьи — в том числе созданной в YouBoost.
  Future<void> configureHousehold({
    required String fid,
    required String uid,
    required String memberName,
    String? householdName,
    required List<String> rooms,
    required List<String> modifiers,
    required String petType,
    required String parentPin,
  }) async {
    if (!Codes.isValidPin(parentPin)) {
      throw UserFacingException('PIN-код должен состоять из 4 цифр');
    }
    final batch = paths.db.batch();
    batch.set(paths.household(fid), {
      if (householdName != null && householdName.trim().isNotEmpty) 'name': householdName.trim(),
      'ownerUid': uid,
      'parentPinHash': Codes.hashPin(parentPin, salt: fid),
      'inviteCode': null,
      'inviteCodeExpires': null,
      'modifiers': modifiers,
      'rooms': rooms,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (householdName != null && householdName.trim().isNotEmpty) {
      batch.update(paths.family(fid), {'name': householdName.trim()});
    }
    batch.set(paths.memberStats(fid).doc(uid), {
      'uid': uid,
      'name': memberName.trim(),
      'petType': petType,
      'coinsBalance': FieldValue.increment(0),
      'streakCount': FieldValue.increment(0),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Второй взрослый присоединяется по коду (создан в любом из приложений).
  Future<String> joinAsParent({
    required String uid,
    required String name,
    required String petType,
    required String code,
  }) async {
    final c = await codes.resolve(code);
    if (c.isChild) {
      throw UserFacingException('Это код телефона ребёнка, а не код для взрослого');
    }
    // Последовательно, как в YouBoost: следующие записи разрешены правилами
    // только после того, как пользователь стал участником семьи.
    await paths.familyMembers(c.fid).doc(uid).set({
      'role': FamilyRole.parent,
      'code': c.code,
      'name': name.trim(),
    });
    await paths.kidsUsers.doc(uid).set({'fid': c.fid});
    await paths.family(c.fid).update({'parents.$uid': name.trim().split(' ').first});
    await paths.memberStats(c.fid).doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'petType': petType,
      'coinsBalance': FieldValue.increment(0),
      'streakCount': FieldValue.increment(0),
    }, SetOptions(merge: true));
    return c.fid;
  }

  /// Код приглашения второго взрослого (действует сутки).
  Future<FamilyCode> createParentInvite({required String fid, required String byUid}) async {
    final c = await codes.create(fid: fid, role: FamilyRole.parent, byUid: byUid);
    await paths.household(fid).set({
      'inviteCode': c.code,
      'inviteCodeExpires': Timestamp.fromDate(c.expires),
    }, SetOptions(merge: true));
    return c;
  }

  Future<FamilyCode> resolveCode(String code) => codes.resolve(code);

  Stream<DocMap?> watchFamily(String fid) =>
      paths.family(fid).snapshots().map((s) => s.exists ? s.data() : null);

  Stream<DocMap?> watchHouseholdExt(String fid) =>
      paths.household(fid).snapshots().map((s) => s.exists ? s.data() : null);

  /// Все участники семьи (родители и телефоны детей): uid → данные.
  Stream<Map<String, DocMap>> watchFamilyMembers(String fid) =>
      paths.familyMembers(fid).snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  Stream<Map<String, DocMap>> watchMemberStats(String fid) =>
      paths.memberStats(fid).snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  bool verifyPin(Household household, String pin) =>
      Codes.verifyPin(pin, salt: household.id, hash: household.parentPinHash);

  Future<void> changePin(String fid, String newPin) {
    if (!Codes.isValidPin(newPin)) {
      throw UserFacingException('PIN-код должен состоять из 4 цифр');
    }
    return paths.household(fid).set({
      'parentPinHash': Codes.hashPin(newPin, salt: fid),
    }, SetOptions(merge: true));
  }
}
