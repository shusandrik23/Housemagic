import 'package:clean_page/app.dart';
import 'package:clean_page/core/age_group.dart';
import 'package:clean_page/core/shopping_logic.dart';
import 'package:clean_page/services/app_services.dart';
import 'package:clean_page/services/biometric_service.dart';
import 'package:clean_page/state/session_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoBiometrics extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpFor(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('не вошёл → экран входа с Google и кодом приглашения', (tester) async {
    final services = AppServices.withBackends(
      auth: MockFirebaseAuth(),
      db: FakeFirebaseFirestore(),
    );
    await tester.pumpWidget(CleanPageApp(services: services));
    await pumpFor(tester);
    expect(find.text('Чистый Лист'), findsOneWidget);
    expect(find.text('Войти через Google'), findsOneWidget);
    await tester.tap(find.text('Войти по коду приглашения в дом'));
    await tester.pump();
    expect(find.byKey(const ValueKey('invite-code')), findsOneWidget);
  });

  testWidgets('первый вход → профиль users/{uid} и выбор «Создать / Присоединиться»', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'mom', email: 'anya@example.com', displayName: 'Аня Иванова'),
    );
    await tester.pumpWidget(
      CleanPageApp(
        services: AppServices.withBackends(auth: auth, db: db),
      ),
    );
    await pumpFor(tester);
    expect(find.text('Создать новый Дом'), findsOneWidget);
    expect(find.text('Присоединиться к Дому'), findsOneWidget);
    final user = (await db.doc('users/mom').get()).data()!;
    expect(user['email'], 'anya@example.com');
    expect(user['displayName'], 'Аня Иванова');
  });

  testWidgets('семья из YouBoost без надстройки → экран настройки Дома', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('kidsUsers/dad').set({'fid': 'yb'});
    await db.doc('kidsFamilies/yb').set({'name': 'Семья', 'owner': 'dad', 'parents': {}});
    await db.doc('kidsFamilies/yb/members/dad').set({'role': 'parent', 'name': 'Папа'});
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'dad'));
    await tester.pumpWidget(
      CleanPageApp(
        services: AppServices.withBackends(auth: auth, db: db),
      ),
    );
    await pumpFor(tester);
    expect(find.text('Настройка Дома'), findsOneWidget);
  });

  testWidgets('детский режим: вход из переключателя и выход только по PIN', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();
    final services = AppServices.withBackends(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'mom', displayName: 'Аня'),
      ),
      db: db,
      biometrics: _NoBiometrics(),
    );
    final fid = await services.households.createHousehold(
      ownerUid: 'mom',
      ownerName: 'Аня',
      householdName: 'Солнечный дом',
      rooms: const ['Кухня'],
      modifiers: const [],
      petType: 'hedgehog',
      parentPin: '2468',
    );
    await services.children.addChild(
      householdId: fid,
      name: 'Миша',
      ageGroup: AgeGroup.middle,
      petType: 'dragon',
      createdByUid: 'mom',
    );

    await tester.pumpWidget(CleanPageApp(services: services));
    await pumpFor(tester);
    expect(find.text('Солнечный дом'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('profile-switcher')));
    await pumpFor(tester, 6);
    await tester.tap(find.text('🐉 Миша — детский режим'));
    await pumpFor(tester);
    expect(find.text('Академия Юных Хранителей'), findsOneWidget);
    expect(find.text('Привет, Миша!'), findsOneWidget);

    Future<void> enterPin(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-key-$d')));
        await tester.pump();
      }
      await pumpFor(tester, 6);
    }

    await tester.tap(find.byKey(const ValueKey('exit-child-mode')));
    await pumpFor(tester, 6);
    await enterPin('1111');
    expect(find.text('Неверный PIN-код'), findsOneWidget);
    await enterPin('2468');
    expect(find.text('Академия Юных Хранителей'), findsNothing);

    final session = Provider.of<SessionController>(
      tester.element(find.byType(RootSwitch)),
      listen: false,
    );
    expect(session.inChildMode, isFalse);
  });

  testWidgets('покупки: две вкладки, «Закончилось средство» уходит в хозтовары', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();
    final services = AppServices.withBackends(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'mom', displayName: 'Аня'),
      ),
      db: db,
    );
    final fid = await services.households.createHousehold(
      ownerUid: 'mom',
      ownerName: 'Аня',
      householdName: 'Дом',
      rooms: const ['Кухня'],
      modifiers: const ['cat'],
      petType: 'hedgehog',
      parentPin: '2468',
    );
    await tester.pumpWidget(CleanPageApp(services: services));
    await pumpFor(tester);

    await tester.tap(find.byKey(const ValueKey('out-of-supplies')));
    await pumpFor(tester, 8);
    await tester.tap(find.text('Наполнитель для лотка'));
    await pumpFor(tester, 8);
    await tester.tap(find.text('Готово'));
    await pumpFor(tester, 8);

    final supplies = await services.shopping
        .watchList(fid, ShoppingListType.householdSupplies)
        .first;
    expect(supplies.single.title, 'Наполнитель для лотка');
    expect(supplies.single.category, ShoppingCategories.pets);
    expect(await services.shopping.watchList(fid, ShoppingListType.grocery).first, isEmpty);

    await tester.tap(find.text('Покупки'));
    await pumpFor(tester);
    expect(find.text('🥕 Продукты'), findsOneWidget);
    expect(find.text('🧽 Для дома и уборки'), findsOneWidget);
    await tester.tap(find.text('🧽 Для дома и уборки'));
    await pumpFor(tester, 12);
    expect(find.text('Наполнитель для лотка'), findsOneWidget);
  });
}
