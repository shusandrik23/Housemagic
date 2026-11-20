import 'package:clean_page/core/age_group.dart';
import 'package:clean_page/core/codes.dart';
import 'package:clean_page/core/shopping_logic.dart';
import 'package:clean_page/models/active_profile.dart';
import 'package:clean_page/models/child_quest.dart';
import 'package:clean_page/repositories/children_repository.dart';
import 'package:clean_page/repositories/family_codes.dart';
import 'package:clean_page/repositories/household_repository.dart';
import 'package:clean_page/repositories/paths.dart';
import 'package:clean_page/repositories/quest_repository.dart';
import 'package:clean_page/repositories/shopping_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late HouseholdRepository households;
  late ChildrenRepository children;
  late QuestRepository quests;
  late ShoppingRepository shopping;

  setUp(() {
    db = FakeFirebaseFirestore();
    households = HouseholdRepository(db);
    children = ChildrenRepository(db);
    quests = QuestRepository(db, clock: () => DateTime(2026, 11, 20, 12));
    shopping = ShoppingRepository(db);
  });

  Future<String> createHouse() => households.createHousehold(
    ownerUid: 'mom',
    ownerName: 'Мама Аня',
    householdName: 'Солнечный дом',
    rooms: const ['Кухня', 'Ванная'],
    modifiers: const ['cat'],
    petType: 'hedgehog',
    parentPin: '1234',
  );

  group('Дом и общая семья YouBoost', () {
    test('создание Дома пишет семью в формате YouBoost и надстройку', () async {
      final fid = await createHouse();

      final family = (await db.collection('kidsFamilies').doc(fid).get()).data()!;
      expect(family['owner'], 'mom');
      expect(family['name'], 'Солнечный дом');
      expect(family['parents'], {'mom': 'Мама'});
      expect(family['rewards'], isEmpty);
      expect(family['challenges'], isEmpty);
      expect(family['createdAt'], isA<String>());

      final member = (await db.doc('kidsFamilies/$fid/members/mom').get()).data()!;
      expect(member, {'role': 'parent', 'name': 'Мама Аня'});
      expect((await db.doc('kidsUsers/mom').get()).data(), {'fid': fid});

      final ext = (await db.doc('households/$fid').get()).data()!;
      expect(ext['rooms'], ['Кухня', 'Ванная']);
      expect(ext['modifiers'], ['cat']);
      expect(ext['parentPinHash'], Codes.hashPin('1234', salt: fid));

      final stats = (await db.doc('households/$fid/members/mom').get()).data()!;
      expect(stats['coinsBalance'], 0);
      expect(stats['petType'], 'hedgehog');
    });

    test('семью, созданную в YouBoost, можно донастроить', () async {
      await db.doc('kidsFamilies/yb1').set({
        'name': '',
        'owner': 'dad',
        'parents': {'dad': 'Папа'},
      });
      await db.doc('kidsFamilies/yb1/members/dad').set({'role': 'parent', 'name': 'Папа'});
      await households.configureHousehold(
        fid: 'yb1',
        uid: 'dad',
        memberName: 'Папа',
        householdName: 'Дом у моря',
        rooms: const ['Кухня'],
        modifiers: const [],
        petType: 'owl',
        parentPin: '0000',
      );
      expect((await db.doc('households/yb1').get()).exists, isTrue);
      expect((await db.doc('kidsFamilies/yb1').get()).data()!['name'], 'Дом у моря');
    });

    test('второй взрослый присоединяется по коду (и из YouBoost тоже)', () async {
      final fid = await createHouse();
      final invite = await households.createParentInvite(fid: fid, byUid: 'mom');
      expect(Codes.isValidFamilyCode(invite.code), isTrue);
      final codeDoc = (await db.doc('kidsCodes/${invite.code}').get()).data()!;
      expect(codeDoc['role'], 'parent');
      expect(codeDoc['fid'], fid);
      expect(codeDoc['expires'], isA<Timestamp>());

      await households.joinAsParent(
        uid: 'dad',
        name: 'Папа Олег',
        petType: 'owl',
        code: invite.code.toLowerCase(),
      );
      expect((await db.doc('kidsFamilies/$fid/members/dad').get()).data(), {
        'role': 'parent',
        'code': invite.code,
        'name': 'Папа Олег',
      });
      expect((await db.doc('kidsUsers/dad').get()).data(), {'fid': fid});
      expect((await db.doc('kidsFamilies/$fid').get()).data()!['parents']['dad'], 'Папа');
    });

    test('просроченный код отклоняется', () async {
      final codes = FamilyCodes(Paths(db), clock: () => DateTime(2030));
      await db.doc('kidsCodes/ABCDEF').set({
        'fid': 'f',
        'role': 'parent',
        'kidId': null,
        'by': 'x',
        'expires': Timestamp.fromDate(DateTime(2029)),
      });
      expect(() => codes.resolve('ABCDEF'), throwsA(isA<UserFacingException>()));
      expect(() => codes.resolve('123'), throwsA(isA<UserFacingException>()));
    });
  });

  group('Дети', () {
    test('ребёнок создаётся в общей карточке YouBoost и в надстройке', () async {
      final fid = await createHouse();
      final kidId = await children.addChild(
        householdId: fid,
        name: 'Миша',
        ageGroup: AgeGroup.small,
        petType: 'dragon',
        createdByUid: 'mom',
      );
      final kid = (await db.doc('kidsFamilies/$fid/kids/$kidId').get()).data()!;
      expect(kid['name'], 'Миша');
      expect(kid['age'], 5);
      expect(kid['habits'], isEmpty);
      expect(kid['pet'], isNull);
      final ext = (await db.doc('households/$fid/children/$kidId').get()).data()!;
      expect(ext['ageGroup'], '4-6');
      expect(ext['goldButtons'], 0);
      expect(ext['isManagedLocally'], isTrue);
    });

    test('привязка телефона ребёнка по коду', () async {
      final fid = await createHouse();
      final kidId = await children.addChild(
        householdId: fid,
        name: 'Миша',
        ageGroup: AgeGroup.middle,
        petType: 'fox',
        createdByUid: 'mom',
      );
      final code = await children.createLinkCode(
        householdId: fid,
        childId: kidId,
        createdByUid: 'mom',
      );
      expect(code.isChild, isTrue);

      // Код взрослого нельзя использовать как код ребёнка и наоборот.
      expect(
        () => households.joinAsParent(uid: 'x', name: 'X', petType: 'cat', code: code.code),
        throwsA(isA<UserFacingException>()),
      );

      final result = await children.linkDevice(deviceUid: 'kidPhone', code: code.code);
      expect(result.childId, kidId);
      final member = (await db.doc('kidsFamilies/$fid/members/kidPhone').get()).data()!;
      expect(member['role'], 'child');
      expect(member['kidId'], kidId);
      expect((await db.doc('kidsUsers/kidPhone').get()).data(), {'fid': fid});
    });
  });

  group('Квесты', () {
    test('фото → pending_approval → «Принять ✨» начисляет пуговицы и пишет в альбом', () async {
      final fid = await createHouse();
      final kidId = await children.addChild(
        householdId: fid,
        name: 'Миша',
        ageGroup: AgeGroup.middle,
        petType: 'fox',
        createdByUid: 'mom',
      );
      final questId = await quests.createQuest(
        householdId: fid,
        childId: kidId,
        title: 'Собери носки',
        monster: 'Носочный Гоблин',
        emoji: '🧦',
        durationMinutes: 10,
        rewardButtons: 8,
        createdByUid: 'mom',
      );
      await quests.submitForApproval(
        householdId: fid,
        questId: questId,
        photoUrl: 'https://x/after.jpg',
      );
      final pending = await quests.watchPendingApprovals(fid).first;
      expect(pending.single.status, QuestStatus.pendingApproval);

      await quests.approve(householdId: fid, questId: questId, approverUid: 'mom');
      final quest = (await db.doc('households/$fid/child_quests/$questId').get()).data()!;
      expect(quest['status'], 'completed');
      final ext = (await db.doc('households/$fid/children/$kidId').get()).data()!;
      expect(ext['goldButtons'], 8);
      expect(ext['streakCount'], 1);
      expect(ext['lastQuestDay'], '2026-11-20');
      final album = await db.collection('households/$fid/victory_album').get();
      expect(album.docs.single.data()['childName'], 'Миша');

      // Повторное подтверждение не начисляет второй раз.
      await quests.approve(householdId: fid, questId: questId, approverUid: 'mom');
      expect((await db.doc('households/$fid/children/$kidId').get()).data()!['goldButtons'], 8);
    });
  });

  group('Покупки', () {
    test('«Закончилось средство» пишет только в household_supplies и без дублей', () async {
      final fid = await createHouse();
      final created = await shopping.addSupplyFromTask(
        householdId: fid,
        title: 'Губки',
        addedByUid: 'mom',
        addedByName: 'Мама',
      );
      final dup = await shopping.addSupplyFromTask(
        householdId: fid,
        title: 'губки',
        addedByUid: 'mom',
        addedByName: 'Мама',
      );
      expect(created, isTrue);
      expect(dup, isFalse);
      final supplies = await shopping.watchList(fid, ShoppingListType.householdSupplies).first;
      final grocery = await shopping.watchList(fid, ShoppingListType.grocery).first;
      expect(supplies.single.title, 'Губки');
      expect(supplies.single.isAutoSuggested, isTrue);
      expect(supplies.single.category, ShoppingCategories.cleaningSupplies);
      expect(supplies.single.quantity, isNull);
      expect(grocery, isEmpty);
    });

    test('«Завершить поход в магазин» архивирует купленное и награждает', () async {
      final fid = await createHouse();
      final a = await shopping.addItem(
        householdId: fid,
        listType: ShoppingListType.grocery,
        title: 'Молоко',
        quantity: '2 л',
        addedByUid: 'mom',
        addedByName: 'Мама',
      );
      await shopping.addItem(
        householdId: fid,
        listType: ShoppingListType.grocery,
        title: 'Хлеб',
        addedByUid: 'mom',
        addedByName: 'Мама',
      );
      await shopping.setBought(householdId: fid, itemId: a, isBought: true, byUid: 'mom');

      final reward = await shopping.completeTrip(
        householdId: fid,
        listType: ShoppingListType.grocery,
        byUid: 'mom',
        profile: const AdultActiveProfile(uid: 'mom', displayName: 'Мама'),
      );
      expect(reward, 25);
      final left = await shopping.watchList(fid, ShoppingListType.grocery).first;
      expect(left.single.title, 'Хлеб');
      final trips = await db.collection('households/$fid/shopping_trips').get();
      expect(trips.docs.single.data()['itemCount'], 1);
      expect((await db.doc('households/$fid/members/mom').get()).data()!['coinsBalance'], 25);
    });

    test('в детском режиме награда идёт ребёнку', () async {
      final fid = await createHouse();
      final kidId = await children.addChild(
        householdId: fid,
        name: 'Миша',
        ageGroup: AgeGroup.middle,
        petType: 'fox',
        createdByUid: 'mom',
      );
      final id = await shopping.addItem(
        householdId: fid,
        listType: ShoppingListType.householdSupplies,
        title: 'Лампочки',
        addedByUid: 'mom',
        addedByName: 'Мама',
      );
      await shopping.setBought(householdId: fid, itemId: id, isBought: true, byUid: 'mom');
      await shopping.completeTrip(
        householdId: fid,
        listType: ShoppingListType.householdSupplies,
        byUid: 'mom',
        profile: ChildActiveProfile(childId: kidId, displayName: 'Миша'),
      );
      expect((await db.doc('households/$fid/children/$kidId').get()).data()!['goldButtons'], 25);
    });

    test('нельзя завершить поход без купленного', () async {
      final fid = await createHouse();
      expect(
        () => shopping.completeTrip(
          householdId: fid,
          listType: ShoppingListType.grocery,
          byUid: 'mom',
          profile: const AdultActiveProfile(uid: 'mom', displayName: 'Мама'),
        ),
        throwsA(isA<UserFacingException>()),
      );
    });
  });
}
