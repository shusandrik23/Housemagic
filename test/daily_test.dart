import 'package:clean_page/core/daily.dart';
import 'package:clean_page/models/household.dart';
import 'package:clean_page/repositories/daily_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Мини-задача дня', () {
    test('одна на день, меняется со днём', () {
      final a = MiniTask.forDay(DateTime(2026, 11, 20, 8));
      final b = MiniTask.forDay(DateTime(2026, 11, 20, 23));
      final c = MiniTask.forDay(DateTime(2026, 11, 21));
      expect(a.id, b.id);
      expect(a.id, isNot(c.id));
    });

    test('учитывает комнаты и модификаторы дома', () {
      for (var d = 0; d < 60; d++) {
        final t = MiniTask.forDay(
          DateTime(2026, 1, 1).add(Duration(days: d)),
          rooms: const ['Кухня'],
          modifiers: const [],
        );
        expect(t.room == null || t.room == 'Кухня', isTrue);
        expect(t.modifier, isNull);
      }
    });
  });

  group('Правила дома', () {
    test('по умолчанию — стандартный набор, иначе свой список', () {
      expect(
        Household.fromParts(id: 'f', family: const {}, ext: const {}).dailyRules,
        DailyRule.defaults,
      );
      final custom = Household.fromParts(
        id: 'f',
        family: const {},
        ext: const {
          'dailyRules': [
            {'id': 'a', 'title': 'Полить цветы', 'period': 'evening'},
            {'id': 'b', 'title': ''},
          ],
        },
      ).dailyRules;
      expect(custom.single.title, 'Полить цветы');
      expect(custom.single.period, RulePeriod.evening);
    });
  });

  group('DailyRepository', () {
    late FakeFirebaseFirestore db;
    late DailyRepository repo;
    var now = DateTime(2026, 11, 20, 9);

    setUp(() {
      db = FakeFirebaseFirestore();
      now = DateTime(2026, 11, 20, 9);
      repo = DailyRepository(db, clock: () => now);
    });

    test('все правила за день → +10 пуговиц и серия, один раз', () async {
      const ids = ['a', 'b'];
      expect(await repo.setRule(fid: 'f', uid: 'u', ruleId: 'a', done: true, allRuleIds: ids), 0);
      expect(await repo.setRule(fid: 'f', uid: 'u', ruleId: 'b', done: true, allRuleIds: ids), 10);
      // снять и поставить снова — повторной награды нет
      await repo.setRule(fid: 'f', uid: 'u', ruleId: 'b', done: false, allRuleIds: ids);
      expect(await repo.setRule(fid: 'f', uid: 'u', ruleId: 'b', done: true, allRuleIds: ids), 0);
      var stats = (await db.doc('households/f/members/u').get()).data()!;
      expect(stats['coinsBalance'], 10);
      expect(stats['streakCount'], 1);

      // следующий день — серия 2
      now = DateTime(2026, 11, 21, 9);
      await repo.setRule(fid: 'f', uid: 'u', ruleId: 'a', done: true, allRuleIds: ids);
      await repo.setRule(fid: 'f', uid: 'u', ruleId: 'b', done: true, allRuleIds: ids);
      stats = (await db.doc('households/f/members/u').get()).data()!;
      expect(stats['coinsBalance'], 20);
      expect(stats['streakCount'], 2);
      final day = await repo.watchDay('f', 'u', '2026-11-21').first;
      expect(day.rulesDone, {'a', 'b'});
    });

    test('мини-задача: +5 один раз в день', () async {
      expect(await repo.completeMiniTask(fid: 'f', uid: 'u', taskId: 'handles'), 5);
      expect(await repo.completeMiniTask(fid: 'f', uid: 'u', taskId: 'handles'), 0);
      expect((await db.doc('households/f/members/u').get()).data()!['coinsBalance'], 5);
      expect((await repo.watchDay('f', 'u', '2026-11-20').first).miniDone, isTrue);
    });

    test('свои правила сохраняются в доме', () async {
      await repo.saveRules('f', const [
        DailyRule(id: 'x', title: 'Вынести мусор', period: RulePeriod.evening),
      ]);
      final ext = (await db.doc('households/f').get()).data()!;
      expect(ext['dailyRules'], [
        {'id': 'x', 'title': 'Вынести мусор', 'period': 'evening'},
      ]);
    });
  });
}
