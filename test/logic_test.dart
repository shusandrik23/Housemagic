import 'dart:math';

import 'package:clean_page/core/age_group.dart';
import 'package:clean_page/core/codes.dart';
import 'package:clean_page/core/shopping_logic.dart';
import 'package:clean_page/core/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Codes', () {
    test('код семьи — 6 символов из алфавита YouBoost', () {
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = Codes.familyCode(r);
        expect(Codes.isValidFamilyCode(code), isTrue);
        expect(code.split('').every(Codes.alphabet.contains), isTrue);
      }
    });

    test('normalize убирает мусор и поднимает регистр', () {
      expect(Codes.normalize(' ab3-k9q '), 'AB3K9Q');
    });

    test('PIN хешируется с солью дома', () {
      final h = Codes.hashPin('1234', salt: 'house1');
      expect(h, hasLength(64));
      expect(h, isNot(Codes.hashPin('1234', salt: 'house2')));
      expect(Codes.verifyPin('1234', salt: 'house1', hash: h), isTrue);
      expect(Codes.verifyPin('4321', salt: 'house1', hash: h), isFalse);
      expect(Codes.verifyPin('1234', salt: 'house1', hash: null), isFalse);
      expect(Codes.isValidPin('12a4'), isFalse);
      expect(Codes.isValidPin('0000'), isTrue);
    });
  });

  group('ShoppingLogic', () {
    test('быстрая запись с количеством', () {
      final e = ShoppingLogic.parseQuickEntry('молоко 2 л');
      expect(e.title, 'Молоко');
      expect(e.quantity, '2 л');
      final e2 = ShoppingLogic.parseQuickEntry('Яйца 10 шт');
      expect(e2.title, 'Яйца');
      expect(e2.quantity, '10 шт');
      final e3 = ShoppingLogic.parseQuickEntry('хлеб');
      expect(e3.title, 'Хлеб');
      expect(e3.quantity, isNull);
    });

    test('автокатегории для обоих списков', () {
      expect(
        ShoppingLogic.suggestCategory('Бананы', ShoppingListType.grocery),
        ShoppingCategories.fruitsVeg,
      );
      expect(
        ShoppingLogic.suggestCategory('Кефир', ShoppingListType.grocery),
        ShoppingCategories.dairy,
      );
      expect(
        ShoppingLogic.suggestCategory('Губки', ShoppingListType.householdSupplies),
        ShoppingCategories.cleaningSupplies,
      );
      expect(
        ShoppingLogic.suggestCategory('Лампочка E27', ShoppingListType.householdSupplies),
        ShoppingCategories.repair,
      );
      expect(
        ShoppingLogic.suggestCategory('Корм для кошки', ShoppingListType.householdSupplies),
        ShoppingCategories.pets,
      );
      expect(
        ShoppingLogic.suggestCategory('Неизвестное', ShoppingListType.grocery),
        ShoppingCategories.other,
      );
    });

    test('награда за поход: 25 или 40 пуговиц', () {
      expect(ShoppingLogic.tripReward(0), 0);
      expect(ShoppingLogic.tripReward(3), 25);
      expect(ShoppingLogic.tripReward(10), 40);
    });

    test('подсказки пикера учитывают модификаторы и контекст', () {
      final cleaning = SupplySuggestion.forContext(repair: false, modifiers: const ['cat']);
      expect(cleaning.first.forRepair, isFalse);
      expect(cleaning.any((s) => s.title == 'Наполнитель для лотка'), isTrue);
      expect(cleaning.any((s) => s.title == 'Корм для собаки'), isFalse);
      final repair = SupplySuggestion.forContext(repair: true, modifiers: const []);
      expect(repair.first.forRepair, isTrue);
    });
  });

  group('AgeGroup', () {
    test('значения и таймеры', () {
      expect(AgeGroup.fromValue('4-6').timerMinutes, 5);
      expect(AgeGroup.fromValue('7-10').timerMinutes, 10);
      expect(AgeGroup.fromValue('11+').timerMinutes, 15);
    });

    test('группа по возрасту из карточки YouBoost', () {
      expect(AgeGroup.fromAge(5), AgeGroup.small);
      expect(AgeGroup.fromAge(8), AgeGroup.middle);
      expect(AgeGroup.fromAge(12), AgeGroup.teen);
      expect(AgeGroup.fromAge(null), AgeGroup.middle);
    });
  });

  group('Streak', () {
    final now = DateTime(2026, 11, 20, 18);
    test('вчера → серия растёт', () {
      expect(Streak.next(lastDay: '2026-11-19', current: 3, now: now), 4);
    });
    test('сегодня → без изменений', () {
      expect(Streak.next(lastDay: '2026-11-20', current: 3, now: now), 3);
    });
    test('пропуск → заново', () {
      expect(Streak.next(lastDay: '2026-11-10', current: 7, now: now), 1);
      expect(Streak.next(lastDay: null, current: 0, now: now), 1);
    });
  });
}
